# SQL Saturday Attendee Management

This repository contains scripts and database objects for importing, managing, and printing SQL Saturday attendee data from Eventbrite.

## Features

- PowerShell script to securely fetch attendee data from Eventbrite using SecretManagement
- SQL Server stored procedures and tables for attendee management
- Automated import and print tracking

## Inspiration & Database Design

The database design and much of the workflow were inspired by [Jeff Taylor's SpeedPass blog post](https://www.jefftaylor.io/post/speedpass).  
Special thanks to Jeff for sharing his approach and schema!

## Usage

1. Store your Eventbrite API token securely using PowerShell SecretManagement.
2. Run the PowerShell script to import attendees.
3. Use the provided stored procedures to manage attendee printing and tracking.

## Requirements

- PowerShell 7+
- Microsoft.PowerShell.SecretManagement & SecretStore modules
- SQL Server (tested on SQL Express)