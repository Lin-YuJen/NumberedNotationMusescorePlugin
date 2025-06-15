//https://musescore.org/node/345087
/*-
 * Copyright © 2020, 2021
 *  mirabilos <m@mirbsd.org>
 *
 * Provided that these terms and disclaimer and all copyright notices
 * are retained or reproduced in an accompanying document, permission
 * is granted to deal in this work without restriction, including un‐
 * limited rights to use, publicly perform, distribute, sell, modify,
 * merge, give away, or sublicence.
 *
 * This work is provided “AS IS” and WITHOUT WARRANTY of any kind, to
 * the utmost extent permitted by applicable law, neither express nor
 * implied; without malicious intent or gross negligence. In no event
 * may a licensor, author or contributor be held liable for indirect,
 * direct, other damage, loss, or other issues arising in any way out
 * of dealing in the work, even if advised of the possibility of such
 * damage or existence of a defect, except proven that it results out
 * of said person’s immediate fault when using the work as intended.
 *
 * Makes use of some techniques demonstrated by the MuseScore example
 * plugins. No copyright is claimed for these or the API extracts.
 */
import MuseScore 3.0
import QtQuick 2.9

MuseScore {
    property string pname: "Add (solfege numbers) as lyrics: 五线谱->简谱"
    menuPath: "Plugins." + pname
    version: "20230517A";
    thumbnailName: "solfege_number.png";
    title: "五线谱->简谱"
    description: "This plugin will convert solfege names to numbers: Do, Re, Mi, Fa, So, La, Ti -> 1, 2, 3, 4, 5, 6, 7... Ra, Me, Se, Le, Te -> ♭2, ♭3, ♭5, ♭6, ♭7... Di, Ri, Fi, Si, Li -> ♯1, ♯2, ♯4, ♯5, ♯6";

    id: pluginscope

    Component.onCompleted: {
        if (mscoreMajorVersion >= 4) {
            pluginscope.title = pluginscope.pname
            // some_id.thumbnailName = "thumbnail.png";
            // some_id.categoryCode = "some_caregory";
        }
    }

    function makeSolfaArray() {
        var so2sol = true
        var me2ma = false
        var le2lo = false
        var te2ta = false
        var dobasedminor = false
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

    function nameNote(solfaArray, note, key) {
        return solfaArray[note.tpc1 - key + 1 + 7]  //+1 tpc starts at -1
    }

    function buildMeasureMap(score) {
        var map = {};
        var no = 1;
        var cursor = score.newCursor();
        cursor.rewind(Cursor.SCORE_START);
        while (cursor.measure) {
            var m = cursor.measure;
            var tick = m.firstSegment.tick;
            var tsD = m.timesigActual.denominator;
            var tsN = m.timesigActual.numerator;
            var ticksB = division * 4.0 / tsD;
            var ticksM = ticksB * tsN;
            no += m.noOffset;
            var cur = {
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
        var t = cursor.segment.tick;
        var m = measureMap[cursor.measure.firstSegment.tick];
        var b = "?";
        if (m && t >= m.tick && t < m.past) {
            b = 1 + (t - m.tick) / m.ticksB;
        }
        return "St" + (cursor.staffIdx + 1) +
            " Vc" + (cursor.voice + 1) +
            " Ms" + m.no + " Bt" + b;
    }

    /** signature: applyToSelectionOrScore(cb, ...args) */
    function applyToSelectionOrScore(cb) {
        var args = Array.prototype.slice.call(arguments, 1);
        var staveBeg;
        var staveEnd;
        var tickEnd;
        var rewindMode;
        var toEOF;
        var cursor = curScore.newCursor();
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
        for (var stave = staveBeg; stave <= staveEnd; ++stave) {
            for (var voice = 0; voice < 4; ++voice) {
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
        for (var i = 0; i < cursor.element.lyrics.length; ++i) {
            console.log(showPos(cursor, measureMap) + ": Lyric#" +
                i + " = " + cursor.element.lyrics[i].text);
            /* removeElement was added in 3.3.0 */
            removeElement(cursor.element.lyrics[i]);
        }
    }

    function nameNotes(cursor, measureMap) {
        //console.log(showPos(cursor, measureMap) + ": " +
        //    nameElementType(cursor.element.type));
        if (cursor.element.type !== Element.CHORD)
            return;

        var solfaArray = makeSolfaArray()

        var text = newElement(Element.LYRICS);
        text.text = "";
        var notes = cursor.element.notes;
        var sep = "";
        for (var i = 1; i < notes.length + 1; ++i) {
            text.text += sep + nameNote(solfaArray, notes[notes.length - i], cursor.keySignature);
            // text.text += notes.length;
            sep = "\n";
        }
        if (text.text == "")
            return;
        text.verse = cursor.voice;
        //console.log(showPos(cursor, measureMap) + ": add verse(" +
        //    (text.verse + 1) + ")=" + text.text);
        cursor.element.add(text);
    }

    onRun: {
        curScore.startCmd()
        var measureMap = buildMeasureMap(curScore);
        if (removeElement)
            applyToSelectionOrScore(dropLyrics, measureMap);
        applyToSelectionOrScore(nameNotes, measureMap);
        curScore.endCmd()
    }
}