# Schedule Generator Enhancement: Mixed Event Support

## Overview
Updated the `New-SQLSaturdaySchedule.ps1` script to handle scenarios where regular sessions occur during special events (like lunch time).

## Key Changes Made

### 1. Enhanced Special Event Logic
- **Before**: Special events (lunch, keynote, raffle) would span all columns, hiding any concurrent regular sessions
- **After**: Detects when regular sessions occur during special events and shows both

### 2. New Mixed Event Row Format
- **Special Event Column**: First column shows the special event (lunch, keynote, etc.) in a smaller format
- **Regular Sessions**: Remaining columns show concurrent regular sessions
- **Responsive Design**: Maintains proper styling and spacing

### 3. Updated CSS Styles
Added new CSS classes for mixed event scenarios:
- `.mixed-event-row` - Row styling for mixed events
- `.special-event-small` - Smaller format for special events when sharing space
- `.keynote-title-small`, `.lunch-title-small`, `.raffle-title-small` - Compact titles
- `.keynote-room-small`, `.lunch-room-small`, `.raffle-room-small` - Compact room info

## Use Cases Supported

### Scenario 1: Lunch Session
- **Situation**: A "lunch and learn" session occurs during lunch time
- **Result**: First column shows "🍽️ LUNCH" with location, other columns show the session details

### Scenario 2: Keynote with Concurrent Sessions
- **Situation**: Multiple tracks with one being a keynote
- **Result**: First column shows "🎤 KEYNOTE" with speaker, other columns show concurrent sessions

### Scenario 3: Standard Events (No Change)
- **Situation**: Special event with no concurrent regular sessions
- **Result**: Event spans all columns as before (maintains backward compatibility)

## Technical Implementation

### Detection Logic
```powershell
# Check if there are also regular sessions during this special event time
$regularSessionsInSlot = @()
if ($currentSlot) {
    $regularSessionsInSlot = $currentSlot.rooms | Where-Object { 
        $_.session -and 
        -not $_.session.isServiceSession -and 
        -not $_.session.isPlenumSession 
    }
}
```

### Rendering Logic
- If `$regularSessionsInSlot.Count -gt 0`: Use mixed event format
- If `$regularSessionsInSlot.Count -eq 0`: Use full-span format (existing behavior)

## Benefits

1. **Comprehensive Coverage**: No sessions are hidden or missed
2. **Flexible Layout**: Adapts to different event configurations
3. **Backward Compatible**: Existing events continue to work as before
4. **Clear Visual Distinction**: Mixed events are clearly identifiable
5. **Responsive Design**: Works across different page sizes and orientations

## Testing Recommendations

1. **Test with lunch session**: Event that has both lunch and a concurrent session
2. **Test with keynote**: Keynote with concurrent breakout sessions
3. **Test standard events**: Ensure existing behavior is maintained
4. **Test edge cases**: Multiple concurrent sessions during special events

## Visual Example

```
| Time     | Lunch/Event | Room 1        | Room 2        | Room 3        |
|----------|-------------|---------------|---------------|---------------|
| 12:20 PM | 🍽️ LUNCH   | Session A     | Session B     | (empty)       |
|          | 📍 Atrium  | Speaker Name  | Speaker Name  |               |
```

This enhancement ensures that all sessions are properly displayed regardless of whether they coincide with special events, providing a complete and accurate schedule representation.
