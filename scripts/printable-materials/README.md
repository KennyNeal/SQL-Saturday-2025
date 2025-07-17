# Printable Materials Generation Scripts

## Overview
Scripts for creating printable materials for SQL Saturday events, including SpeedPasses, Stamp Games, and Schedules.

## Scripts

### `Generate-SpeedPasses.ps1`
**Purpose**: Create personalized PDF SpeedPasses with attendee information and QR codes

**Features**:
- Generates HTML and PDF versions of SpeedPasses
- Includes QR codes for quick check-in
- Sponsor logo integration
- Attendee information (name, company, lunch preference)
- vCard QR codes for networking
- Batch processing of all unprinted attendees

**Output Files**:
- `{LastName}_{FirstName}.html` - HTML version for preview
- `{LastName}_{FirstName}.pdf` - PDF for printing and email
- Raw HTML files in `raw/` subfolder

**Usage**:
```powershell
.\Generate-SpeedPasses.ps1
```

### `Generate-StampGame.ps1`
**Purpose**: Create printable Stamp Game sheets with sponsor logos

**Features**:
- Customizable grid layout (default 3 columns)
- Sponsor logo integration from designated folder
- Center logo placement (SQL Saturday logo by default)
- Additional logo placement options (End, Alphabetical, Beginning)
- Landscape PDF format with two sheets per page
- Black squares for grid padding
- Dynamic vertical centering

**Parameters**:
- `-LogoFolder`: Path to sponsor logos folder
- `-CenterLogo`: Path to center logo file
- `-AdditionalLogos`: Array of additional logo paths
- `-AdditionalLogoPlacement`: Placement strategy for additional logos
- `-GridColumns`: Number of columns in grid (default: 3)

**Output**: `Stamp-Game-2025.pdf` in assets/documents

### `Generate-Schedule.ps1` & `New-SQLSaturdaySchedule.ps1`
**Purpose**: Generate printable event schedules

**Features**:
- Session schedule formatting
- Speaker information integration
- Room and time slot organization
- Printable PDF format

**Output**: Schedule PDFs for event distribution

## SpeedPass Design

### Layout
- **Header**: Event logo and branding
- **Attendee Info**: Name, company, job title
- **QR Codes**: 
  - Check-in barcode (from database)
  - vCard for contact sharing
- **Sponsor Section**: Rotating sponsor logos
- **Footer**: Event details and lunch information

### Technical Details
- **Size**: Designed for standard badge holders
- **Format**: HTML to PDF conversion
- **QR Code**: Uses attendee barcode from database
- **Fonts**: Web-safe fonts for consistent rendering

## Configuration

### Paths (Update in script)
```powershell
$BaseFolder = "C:\Path\To\Project"
$sqlSatLogoPath = "assets\images\SQL_2025.png"
$sponsorFolder = "assets\images\Sponsor Logos\Raffle"
$outputFolder = "output\speedpasses"
```

### Database Query
Uses stored procedure: `AttendeesGetUnPrintedOrders`
- Returns attendees who haven't been processed
- Includes barcode, contact info, preferences
- Marks as printed after successful generation

### Sponsor Integration
- Automatically includes sponsor logos
- Supports multiple sponsor tiers
- Randomizes sponsor display order

## Requirements
- **HTML to PDF Converter**: Uses system default (usually browser)
- **QR Code Generation**: Built-in .NET libraries
- **Image Processing**: GDI+ for logo handling
- **Database Access**: SQL Server connection

## Troubleshooting

### Common Issues
- **Missing logos**: Check sponsor folder path
- **PDF generation fails**: Verify HTML validity
- **QR codes not working**: Validate barcode data
- **Database connection**: Verify SQL Server access

### Quality Checks
- Preview HTML files before PDF generation
- Test QR codes with barcode scanner
- Verify sponsor logos display correctly
- Check attendee data completeness

## Usage Examples

```powershell
# Generate speedpasses for all unprinted attendees
.\Generate-SpeedPasses.ps1

# Generate stamp game with custom settings
.\Generate-StampGame.ps1 -GridColumns 4 -AdditionalLogos @("C:\path\to\logo.png")

# Generate stamp game with alphabetical logo placement
.\Generate-StampGame.ps1 -AdditionalLogos @("C:\path\to\gon.png") -AdditionalLogoPlacement "Alphabetical"

# Generate schedules
.\Generate-Schedule.ps1
```
