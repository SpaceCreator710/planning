# Design System

## Visual hierarchy

The interface separates two materials:

1. **Functional glass** — navigation, selectors, floating actions, composer controls and other interactive chrome use native iOS 26 Liquid Glass where appropriate.
2. **Matte content** — tasks, day plans and information surfaces remain calm, opaque enough for legibility, and visually subordinate to the controls.

## Geometry

Primary shapes are circles, capsules, ovals and continuous rounded rectangles. Sharp rectangular chrome is avoided except where platform conventions require it.

## Two-Tone mode

A theme is optional. The default product can run as:

- Light: pure white base + one matte user accent.
- Dark: pure black base + one matte user accent.
- System: follows device appearance while preserving the selected accent.

Accent selection uses HSL controls so saturation and lightness can be kept in a restrained matte range.

## Optional themes

Paper, Spring, Summer, Autumn, Winter, Botanical, Wildlife and Midnight layer restrained craft-inspired palettes and subtle texture over the same interaction system. Themes must not change information architecture or hide features.

## Week board

The week is intentionally horizontal. Each day can expose a miniature task chain and progress state; selecting a day expands its live timeline below. This is a deliberate product distinction from Structured's vertical-week presentation.
