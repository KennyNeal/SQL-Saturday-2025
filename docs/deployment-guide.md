# Deployment Guide

## Pre-Event Checklist

### 2-3 Months Before Event
- [ ] Set up EventBrite event and get API access
- [ ] Configure Sessionize for session management
- [ ] Set up database server
- [ ] Deploy database schema and stored procedures
- [ ] Test attendee import process

### 1 Month Before Event  
- [ ] Import initial attendee list
- [ ] Test SpeedPass generation with sample data
- [ ] Set up email credentials and test sending
- [ ] Generate initial schedule from Sessionize
- [ ] Test all scripts end-to-end

### 1 Week Before Event
- [ ] Final attendee import
- [ ] Generate all SpeedPasses
- [ ] Send SpeedPass emails to attendees
- [ ] Generate final printed schedule
- [ ] Send volunteer recruitment emails

### Day of Event
- [ ] Final attendee check-in system ready
- [ ] Backup SpeedPasses available for printing
- [ ] Database accessible for real-time updates

## Production Environment

### Recommended Infrastructure
- **Database**: SQL Server (not Express for production)
- **Email**: Dedicated SMTP service (not Gmail for high volume)
- **Backup**: Regular database backups
- **Monitoring**: Email delivery tracking

### Security Considerations
- [ ] API tokens stored securely
- [ ] Database access restricted
- [ ] Email credentials encrypted
- [ ] Regular security updates applied

## Scaling for Large Events

### Database Performance
- Add indexes for attendee lookup operations
- Consider database partitioning for 1000+ attendees
- Monitor query performance

### Email Delivery
- Use dedicated SMTP service (SendGrid, AWS SES)
- Implement email delivery tracking
- Handle bounces and failures gracefully

### SpeedPass Generation
- Generate in batches to avoid memory issues
- Consider Azure Functions for cloud processing
- Implement retry logic for failed generations

## Post-Event Tasks

### Data Management
- [ ] Export final attendee statistics
- [ ] Archive event data
- [ ] Clean up temporary files
- [ ] Document lessons learned

### System Maintenance
- [ ] Update scripts based on event feedback
- [ ] Refresh API tokens
- [ ] Plan improvements for next event
