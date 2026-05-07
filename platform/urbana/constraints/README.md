# Urbana Constraints

Keep board-revision-specific XDC files here.

The upstream RealDigital constraints file identifies the 100 MHz board oscillator
as `CLK_100MHZ` and assigns it to package pin `N15`. Use that file as the source
of truth when creating the first committed Urbana XDC.

Do not commit a partial XDC that only happens to work for one smoke test unless
the unused IO policy is explicit and reviewed. For first hardware bring-up, the
minimum useful constraint set is:

- board clock input
- reset or button input
- LED heartbeat output
- configuration voltage properties
- explicit unused output policy

Generated Vivado outputs and downloaded vendor files should stay out of Git
unless their license and revision are recorded.
