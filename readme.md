# SQL Saturday Event Management System

A comprehensive PowerShell-based system for managing SQL Saturday events, from attendee registration to day-of-event operations.

## 🎯 What This System Does

- **Attendee Management**: Import attendees from EventBrite, track registration data
- **SpeedPass Generation**: Create personalized PDF passes with QR codes for quick check-in
- **Email Communications**: Send SpeedPasses and volunteer notifications to attendees
- **Schedule Management**: Generate printable schedules from Sessionize API data
- **Database Operations**: Manage attendee data with SQL Server stored procedures

## 📁 Project Structure

```
├── scripts/
│   ├── attendee-management/     # EventBrite import and attendee processing
│   ├── email-system/           # Email communications and notifications  
│   ├── speedpass-generation/   # PDF SpeedPass creation and management
│   ├── schedule-management/    # Schedule generation from Sessionize
│   └── database-deployment/    # Database schema and stored procedure deployment
├── database/
│   └── sql-project/           # SQL Server database project files
├── assets/
│   ├── images/                # Event logos, sponsor images
│   ├── templates/             # Email and document templates
│   └── documents/             # Sponsorship docs, checklists
├── output/
│   ├── speedpasses/           # Generated SpeedPass PDFs
│   └── schedules/             # Generated schedule documents
├── config/
│   └── settings/              # Configuration files and examples
└── docs/
    ├── setup-guide.md         # Getting started instructions
    ├── database-guide.md      # Database setup and management
    └── deployment-guide.md    # Production deployment instructions
```

## 🚀 Quick Start

1. **Prerequisites**: PowerShell 7+, SQL Server, Required PowerShell modules
2. **Database Setup**: Deploy database schema using scripts in `scripts/database-deployment/`
3. **Configuration**: Set up API keys and connection strings
4. **Import Attendees**: Run EventBrite import script
5. **Generate SpeedPasses**: Create and email SpeedPasses to attendees

## 📖 Detailed Documentation

- [Setup Guide](docs/setup-guide.md) - Complete installation and configuration
- [Database Guide](docs/database-guide.md) - Database schema and stored procedures  
- [Deployment Guide](docs/deployment-guide.md) - Production deployment checklist

## 🤝 Contributing

This project was inspired by [Jeff Taylor's SpeedPass approach](https://www.jefftaylor.io/post/speedpass). 
Thanks to the SQL Saturday community for sharing knowledge and best practices!

## Requirements

- PowerShell 7+
- Microsoft.PowerShell.SecretManagement & SecretStore modules
- SQL Server (tested on SQL Express)