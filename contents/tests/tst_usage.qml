// Unit tests for the pure helpers in js/usage.js.
//
//   ./dev.sh test            (qmltestrunner over contents/tests)
//
// They need no display and no plasmoid host: usage.js takes plain values and
// returns plain values, which is exactly what makes it worth testing here.
import QtQuick
import QtTest

import "../js/usage.js" as Usage

TestCase {
    name: "UsageHelpers"

    function test_usedFraction() {
        compare(Usage.usedFraction({ used: 43, limit: 100 }), 0.43);
        compare(Usage.usedFraction({ used: 5, limit: 0 }), 0, "a zero limit reads as nothing used");
        compare(Usage.usedFraction({ used: 5 }), 0, "a missing limit reads as nothing used");
        compare(Usage.usedFraction(null), 0, "no meter reads as nothing used");
        compare(Usage.usedFraction({ used: 999, limit: 100 }), 1, "clamped above");
        compare(Usage.usedFraction({ used: -5, limit: 100 }), 0, "clamped below");
    }

    function test_displayFractionAndPercent() {
        const meter = { used: 43, limit: 100 };
        compare(Usage.displayFraction(meter, "used"), 0.43);
        compare(Usage.displayFraction(meter, "remaining"), 0.57);
        compare(Usage.displayFraction(meter, "nonsense"), 0.43, "an unknown mode falls back to used");
        compare(Usage.displayFraction(meter, undefined), 0.43);
        compare(Usage.percent(meter, "used"), 43);
        compare(Usage.percent(meter, "remaining"), 57);
    }

    function test_worstMeter() {
        const low = { label: "low", used: 1, limit: 10 };
        const high = { label: "high", used: 9, limit: 10 };
        compare(Usage.worstMeter([low, high]).label, "high");
        compare(Usage.worstMeter([high, low]).label, "high");
        compare(Usage.worstMeter([low, low]).label, "low", "the first of equal shares wins");
        compare(Usage.worstMeter([]), null);
    }

    function test_parseIso() {
        compare(Usage.parseIso(null), null);
        compare(Usage.parseIso(""), null);
        compare(Usage.parseIso("not a date"), null);
        compare(Usage.parseIso("2026-11-01T00:00:00Z").toISOString(), "2026-11-01T00:00:00.000Z");
    }

    function test_durationParts() {
        const sixDays = Usage.durationParts(((6 * 24) + 11) * 3600000);
        compare(JSON.stringify(sixDays), JSON.stringify({ expired: false, days: 6, hours: 11, minutes: 0 }));

        const fiveHours = Usage.durationParts(((5 * 60) + 3) * 60000);
        compare(JSON.stringify(fiveHours), JSON.stringify({ expired: false, days: 0, hours: 5, minutes: 3 }));

        // 59 s is still "0 m" and not expired; the deadline itself is expired.
        compare(JSON.stringify(Usage.durationParts(59000)),
                JSON.stringify({ expired: false, days: 0, hours: 0, minutes: 0 }));
        compare(JSON.stringify(Usage.durationParts(0)),
                JSON.stringify({ expired: true, days: 0, hours: 0, minutes: 0 }));
        compare(JSON.stringify(Usage.durationParts(-1000)),
                JSON.stringify({ expired: true, days: 0, hours: 0, minutes: 0 }));

        compare(Usage.durationParts(NaN), null);
        compare(Usage.durationParts(undefined), null);
    }

    function test_fillWidth() {
        // The reported bug: a meter at 0% drew a sliver because the
        // minimum-visible floor was applied unconditionally.
        compare(Usage.fillWidth(0, 400, 4), 0, "a zero share leaves the track empty");
        compare(Usage.fillWidth(0.0001, 400, 4), 4, "a tiny non-zero share is floored to a sliver");
        compare(Usage.fillWidth(0.43, 400, 4), 172, "a normal share is proportional");
        compare(Usage.fillWidth(1, 400, 4), 400);
        compare(Usage.fillWidth(1.5, 400, 4), 400, "clamped above");
        compare(Usage.fillWidth(-0.2, 400, 4), 0, "clamped below");
        compare(Usage.fillWidth(0.5, 0, 4), 0, "a zero-width track has nothing to fill");
        compare(Usage.fillWidth(0.5, 3, 4), 3, "the floor never exceeds the track");
        compare(Usage.fillWidth(0.5, 400), 200, "no floor given");
        compare(Usage.fillWidth(NaN, 400, 4), 0, "a NaN share draws nothing");
        compare(Usage.fillWidth(0.5, NaN, 4), 0, "a NaN width draws nothing");
    }
}
