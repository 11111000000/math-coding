# site-pure-fp

## Problem

The site needs minimal client-side interactivity (live-filter
on /packets.html, manual theme override). A JS framework would
violate axiom A3's "no framework, no CDN" requirement. Vanilla
JS without functional structure tends toward spaghetti side
effects.

## Desired outcome

Client-side JS is organized as pure functions (filter, render,
escape) over a fetched JSON manifest, with side effects isolated
to one entry-point. Pure functions are unit-tested by Node --test
in CI. Browsers never receive a test framework, only the function
bodies needed for the user-visible behavior.

## Constraints

- No innerHTML on dynamic strings.
- No eval. No document.write.
- All output goes through DOMParser.parseFromString OR
  textContent + setAttribute.
- Pure functions compose: filter must work without render;
  render must work without filter; main may compose both.
- ES modules only (no CommonJS, no AMD, no IIFE globals).
