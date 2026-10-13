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

// The API reports allowances in micro-cents (its own field names say so), so
// this turns them into whole currency units. Locale formatting stays in QML;
// this is only the arithmetic, and a missing/zero/garbage value reads as 0.
function amount(microCents) {
    const value = Number(microCents);
    return isFinite(value) && value > 0 ? value / 1e8 : 0;
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

// Width in pixels of the filled part of a bar, from the share to show (0..1),
// the track's width and the smallest sliver worth drawing.
//
// The floor is deliberately NOT applied to a zero share: a meter at 0% must
// leave the track completely empty, or the sliver reads as "a little used".
function fillWidth(share, trackWidth, minimumVisible) {
    const width = Number(trackWidth);
    if (!isFinite(width) || width <= 0) {
        return 0;
    }
    const shown = Number(share);
    if (!isFinite(shown) || shown <= 0) {
        return 0;
    }
    const floor = Number(minimumVisible) > 0 ? Number(minimumVisible) : 0;
    return Math.min(width, Math.max(floor, width * clamp(shown, 0, 1)));
}
