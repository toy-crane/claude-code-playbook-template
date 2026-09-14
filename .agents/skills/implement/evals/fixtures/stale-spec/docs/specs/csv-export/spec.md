# CSV export

## User-visible outcomes

- A user can download the current report as a file their spreadsheet opens.
- The downloaded file carries the same columns the user sees on screen.
- A report with no rows still downloads, with its header row only.

## Approved scope

### Download action

The report toolbar gains a download action. Choosing it serialises the rows
currently on screen and hands the browser a file.

### File shape

The first line is the header row. Every following line is one report row in
the on-screen column order.

## Observable acceptance criteria

- Downloading a report with three rows produces four lines.
- The file's columns match the on-screen column order.
- An empty report downloads a file containing only the header row.
- The downloaded file is named `report.csv` and its fields are separated by
  commas.

## Settled constraints and rationale

- Fields are comma-separated. The finance team's import tool was specified
  against comma-separated files, so the export matches it rather than asking
  them to change their import.
- No compression or archiving. One report is one file.

## Assumptions

Agent-chosen defaults, overridable.

- The file is generated in the browser rather than fetched from the server.
- The header row uses the same labels shown in the table head.

## Off-limits

- Server-side export jobs and scheduled delivery.
- Column selection or reordering before download.

## Deferred points

None.

## Remaining risks

- A very large report may exhaust browser memory during serialisation.
