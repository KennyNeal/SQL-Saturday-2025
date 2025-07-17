# Schedule Management Scripts

## Overview
Scripts for generating printable event schedules from Sessionize API data.

## Scripts

### `Generate-Schedule.ps1`
**Purpose**: Create printable letter-sized landscape schedule from Sessionize API

**Features**:
- Fetches session data from Sessionize API
- Generates formatted HTML for printing
- Optimized for letter-size paper (landscape)
- Front and back printing support
- Speaker and session information
- Room and time slot organization

**Usage**:
```powershell
.\Generate-Schedule.ps1 -ApiUrl "https://sessionize.com/api/v2/YOUR_EVENT_ID/view/GridSmart"
```

### `New-SQLSaturdaySchedule.ps1`
**Purpose**: Alternative schedule generation with custom formatting

**Features**:
- Custom layout options
- Different format templates
- Enhanced styling capabilities
- Multiple export formats

**Usage**:
```powershell
.\New-SQLSaturdaySchedule.ps1 -SessionizeUrl "YOUR_API_URL"
```

## Schedule Format

### Layout Design
- **Orientation**: Landscape for maximum content
- **Paper Size**: US Letter (8.5" x 11")
- **Printing**: Optimized for duplex (front/back)
- **Font**: Readable sizes for all ages
- **Grid**: Time slots vs. rooms

### Content Sections
- **Header**: Event branding and date
- **Time Grid**: Sessions organized by time and room  
- **Speaker Info**: Names and session titles
- **Footer**: Sponsor acknowledgments and WiFi info

## Sessionize Integration

### API Requirements
- Sessionize event configured with public API access
- GridSmart view enabled for comprehensive data
- Session and speaker data properly populated

### Data Mapping
- **Sessions**: Title, description, level
- **Speakers**: Name, bio, social links
- **Rooms**: Names and capacity
- **Time Slots**: Start/end times, breaks

## Output Files

### Generated Files
- `SQL_Saturday_Schedule_Compact.html` - Main schedule
- `schedule-front.html` - Front page content
- `schedule-back.html` - Back page content (if applicable)

### Location
All schedule files are saved to: `output/schedules/`

## Customization

### Styling
- Modify CSS in script for color scheme changes
- Adjust font sizes for readability
- Update header/footer content

### Layout Options
- Single vs. dual-page formats  
- Portrait vs. landscape orientation
- Grid density (sessions per page)

## Print Guidelines

### Recommended Settings
- **Paper**: US Letter
- **Orientation**: Landscape
- **Margins**: 0.5" all sides
- **Quality**: High (600+ DPI)
- **Color**: Full color or grayscale

### Production Tips
- Print test page first
- Use cardstock for durability
- Consider lamination for outdoor events
- Print extras (10% buffer)
