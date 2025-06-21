import MuseScore 3.0
import QtQuick 2.9

MuseScore {
    property string pname: "Add (solfege numbers) as lyrics: (篠笛)"
    menuPath: "Plugins." + pname
    version: "20250621";
    thumbnailName: "solfege_number.png";
    title: "Add (solfege numbers) as lyrics: (篠笛)"
    description: "This plugin will convert solfege names to numbers: \
        Do, Re, Mi, Fa, So, La, Ti -> 1, 2, 3, 4, 5, 6, 7... \
        Ra, Me, Se, Le, Te -> ♭2, ♭3, ♭5, ♭6, ♭7... \
        Di, Ri, Fi, Si, Li -> ♯1, ♯2, ♯4, ♯5, ♯6";

    id: pluginscope

    Component.onCompleted: {
        if (mscoreMajorVersion >= 4) {
            pluginscope.title = pluginscope.pname
        }
    }

    function makeSolfaArray() {
        let so2sol = true;
        let me2ma = false
        let le2lo = false
        let te2ta = false
        let dobasedminor = false
        // https://musescore.github.io/MuseScore_PluginAPI_Docs/plugins/html/tpc.html
        //+3
        //+7
        //35 tpcs
        //+7

        // accidentals (♯, ♭)

        return ("    4,1,5\
    ,2,6,3,7,♭5,♭2,♭6\
    ,♭3,♭7,4,1,5,2,6\
    ,3,7\
          ,♭5,♭2,♭6,♭3,♭7\
    ,4,1,5,2,6,3,7\
    ,♯4,♯1,♯5,♯2,♯6\
                   ,4,1\
    ,5,2,6,3,7,♯4,♯1\
    ,♯5,♯2,♯6,4,1,5,2\
    "
                .replace(/5/g, so2sol ? '5' : '5')
                .replace(/♭3/g, me2ma ? 'Ma' : '♭3')
                .replace(/♭6/g, le2lo ? 'Lo' : '♭6')
                .replace(/Te/g, te2ta ? 'Ta' : '♭7')
                .replace(/\s/g, '').split(',')
                .slice(dobasedminor ? 0 : 3)
        )

    }


    /**
     * Determines the name of a musical note based on the solfège array, a given note, and a key.
     *
     * @param solfaArray - The array representing solfège notations.
     * @param note - The note object containing pitch and tpc1 properties.
     * @param key - The key value used to compute the note's basic number.
     * @return The computed notation for the note as a kanji character,
     * a numbered notation, or a numbered notation with a dot, depending on the octave.
     */
    function nameNote(solfaArray, note, key) {
        const basicNumber = solfaArray[note.tpc1 - key + 1 + 7]; //+1 tpc starts at -1
        const octave = Math.floor(note.pitch / 12);
        // octave < 6 => 呂音
        if (octave < 6) return '\n' + convertNotationToKanji(basicNumber);
        // octave > 6 => 大甲音
        else if (octave > 6) return addPointOnTheTopOfNumber(basicNumber)
        // octave == 6 => 甲音
        else return '\n' + basicNumber;
    }

    function convertNotationToKanji(notation) {
        const notationMap = {
            '1': '一',
            '♭1': '♭一',
            '♯1': '♯一',
            '2': '二',
            '♭2': '♭二',
            '♯2': '♯二',
            '3': '三',
            '♭3': '♭三',
            '♯3': '♯三',
            '4': '四',
            '♭4': '♭四',
            '♯4': '♯四',
            '5': '五',
            '♭5': '♭五',
            '♯5': '♯五',
            '6': '六',
            '♭6': '♭六',
            '♯6': '♯六',
            '7': '七',
            '♭7': '♭七',
            '♯7': '♯七'
        };
        return notationMap[notation] || notation;
    }

    function addPointOnTheTopOfNumber(notation){
        if (notation.length === 1) {
            return '.\n' + notation;
        } else {
            return ' .\n' + notation;
        }
    }

    function buildMeasureMap(score) {
        let map = {};
        let no = 1;
        let cursor = score.newCursor();
        cursor.rewind(Cursor.SCORE_START);
        while (cursor.measure) {
            let m = cursor.measure;
            let tick = m.firstSegment.tick;
            let tsD = m.timesigActual.denominator;
            let tsN = m.timesigActual.numerator;
            let ticksB = division * 4.0 / tsD;
            let ticksM = ticksB * tsN;
            no += m.noOffset;
            let cur = {
                "tick": tick,
                "tsD": tsD,
                "tsN": tsN,
                "ticksB": ticksB,
                "ticksM": ticksM,
                "past": (tick + ticksM),
                "no": no
            };
            map[cur.tick] = cur;
            console.log(tsN + "/" + tsD + " measure " + no +
                " at tick " + cur.tick + " length " + ticksM);
            if (!m.irregular)
                ++no;
            cursor.nextMeasure();
        }
        return map;
    }

    function showPos(cursor, measureMap) {
        let t = cursor.segment.tick;
        let m = measureMap[cursor.measure.firstSegment.tick];
        let b = "?";
        if (m && t >= m.tick && t < m.past) {
            b = 1 + (t - m.tick) / m.ticksB;
        }
        return "St" + (cursor.staffIdx + 1) +
            " Vc" + (cursor.voice + 1) +
            " Ms" + m.no + " Bt" + b;
    }

    /** signature: applyToSelectionOrScore(cb, ...args) */
    function applyToSelectionOrScore(cb) {
        let args = Array.prototype.slice.call(arguments, 1);
        let staveBeg;
        let staveEnd;
        let tickEnd;
        let rewindMode;
        let toEOF;
        let cursor = curScore.newCursor();
        cursor.rewind(Cursor.SELECTION_START);
        if (cursor.segment) {
            staveBeg = cursor.staffIdx;
            cursor.rewind(Cursor.SELECTION_END);
            staveEnd = cursor.staffIdx;
            if (!cursor.tick) {
                /*
                 * This happens when the selection goes to the
                 * end of the score — rewind() jumps behind the
                 * last segment, setting tick = 0.
                 */
                toEOF = true;
            } else {
                toEOF = false;
                tickEnd = cursor.tick;
            }
            rewindMode = Cursor.SELECTION_START;
        } else {
            /* no selection */
            staveBeg = 0;
            staveEnd = curScore.nstaves - 1;
            toEOF = true;
            rewindMode = Cursor.SCORE_START;
        }
        for (let stave = staveBeg; stave <= staveEnd; ++stave) {
            for (let voice = 0; voice < 4; ++voice) {
                cursor.staffIdx = stave;
                cursor.voice = voice;
                cursor.rewind(rewindMode);
                /*XXX https://musescore.org/en/node/301846 */
                cursor.staffIdx = stave;
                cursor.voice = voice;
                while (cursor.segment &&
                    (toEOF || cursor.tick < tickEnd)) {
                    if (cursor.element)
                        cb.apply(null,
                            [cursor].concat(args));
                    cursor.next();
                }
            }
        }
    }

    function dropLyrics(cursor, measureMap) {
        if (!cursor.element.lyrics)
            return;
        for (let i = 0; i < cursor.element.lyrics.length; ++i) {
            console.log(showPos(cursor, measureMap) + ": Lyric#" +
                i + " = " + cursor.element.lyrics[i].text);
            /* removeElement was added in 3.3.0 */
            removeElement(cursor.element.lyrics[i]);
        }
    }

    function nameNotes(cursor, measureMap) {
        if (cursor.element.type !== Element.CHORD) return;

        let solfaArray = makeSolfaArray()

        let text = newElement(Element.LYRICS);
        text.text = "";
        let notes = cursor.element.notes;
        let sep = "";
        for (let i = 1; i < notes.length + 1; ++i) {
            text.text += sep + nameNote(solfaArray, notes[notes.length - i], cursor.keySignature);
            // text.text += notes.length;
            sep = "\n";
        }
        if (text.text === "") return;
        text.verse = cursor.voice;
        cursor.element.add(text);
    }

    onRun: {
        curScore.startCmd()
        let measureMap = buildMeasureMap(curScore);
        if (removeElement)
            applyToSelectionOrScore(dropLyrics, measureMap);
        applyToSelectionOrScore(nameNotes, measureMap);
        curScore.endCmd()
    }
}