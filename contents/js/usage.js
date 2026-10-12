// Pure derivation helpers shared by the plasmoid's QML files.
//
// Nothing here touches i18n, Plasmoid or the theme: the QML side reads the
// settings and passes plain values in. That keeps every binding that calls into
// this file dependency-tracked, and keeps the arithmetic testable on its own.
.pragma library

function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
}

// Share of a meter's allowance that has been used, clamped to 0..1.
function usedFraction(meter) {
    if (!meter || !meter.limit || meter.limit <= 0) {
        return 0;
    }
    return clamp(meter.used / meter.limit, 0, 1);
}

// The share the UI shows: used, or what is left of the allowance.
function displayFraction(meter, percentMode) {
    const used = usedFraction(meter);
    return percentMode === "remaining" ? 1 - used : used;
}

// Whole percentage for display, in the mode the user picked.
function percent(meter, percentMode) {
    return Math.round(displayFraction(meter, percentMode) * 100);
}

// The meter with the highest used share, or null for an empty list. The tray
// text and the tooltip both summarize "the worst meter".
function worstMeter(meters) {
    let worst = null;
    for (const meter of meters) {
        if (worst === null || usedFraction(meter) > usedFraction(worst)) {
            worst = meter;
        }
    }
    return worst;
}

// Parse an ISO timestamp, returning null for anything unusable.
function parseIso(iso) {
    if (!iso) {
        return null;
    }
    const date = new Date(iso);
    return isNaN(date.getTime()) ? null : date;
}

// Split a duration into whole days, hours and minutes. `expired` is true when
// the deadline is already behind us; null when the input is not a number.
function durationParts(ms) {
    if (!isFinite(ms)) {
        return null;
    }
    if (ms <= 0) {
        return { expired: true, days: 0, hours: 0, minutes: 0 };
    }
    const totalMinutes = Math.floor(ms / 60000);
    return {
        expired: false,
        days: Math.floor(totalMinutes / 1440),
        hours: Math.floor((totalMinutes % 1440) / 60),
        minutes: totalMinutes % 60
    };
}
