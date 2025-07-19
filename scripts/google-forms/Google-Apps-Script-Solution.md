# Google Apps Script Solution for Creating Feedback Forms

Since the Google Forms API doesn't support creating forms, we'll use Google Apps Script instead.

## Setup Instructions

### Step 1: Create Apps Script Project
1. Go to https://script.google.com
2. Click "New Project"
3. Name it "SQL Saturday Form Generator"

### Step 2: Replace Code.gs with this script:

```javascript
function createSessionFeedbackForms() {
  // Session data from Sessionize API
  const sessions = getSessionData();
  
  const results = [];
  const folderId = createFormsFolder();
  
  sessions.forEach(session => {
    try {
      const form = createFeedbackForm(session, folderId);
      results.push({
        sessionTitle: session.title,
        speaker: session.speakers.map(s => s.name).join(', '),
        formUrl: form.getPublishedUrl(),
        editUrl: form.getEditUrl(),
        status: 'Created'
      });
      
      console.log(`✓ Created form for: ${session.title}`);
      
    } catch (error) {
      console.error(`❌ Failed to create form for: ${session.title}`, error);
      results.push({
        sessionTitle: session.title,
        speaker: session.speakers.map(s => s.name).join(', '),
        formUrl: 'ERROR',
        editUrl: 'ERROR',
        status: `Error: ${error.message}`
      });
    }
  });
  
  // Export results to Google Sheets
  exportResultsToSheet(results);
  
  console.log(`🎉 Process completed! Created ${results.filter(r => r.status === 'Created').length} forms`);
  return results;
}

function createFeedbackForm(session, folderId) {
  // Create the form
  const form = FormApp.create(`SQL Saturday 2025 - ${session.title} - Feedback`);
  
  // Move to folder
  const file = DriveApp.getFileById(form.getId());
  DriveApp.getFolderById(folderId).addFile(file);
  DriveApp.getRootFolder().removeFile(file);
  
  // Set description
  const speakerNames = session.speakers.map(s => s.name).join(', ');
  const sessionTime = session.startsAt ? new Date(session.startsAt).toLocaleTimeString() : '';
  
  form.setDescription(
    `Session: ${session.title}\n` +
    `Speaker(s): ${speakerNames}\n` +
    `Time: ${sessionTime}\n` +
    `Room: ${session.room}\n\n` +
    `Your feedback helps speakers improve and helps us plan better events!`
  );
  
  // Add rating questions (1-5 scale)
  const ratingQuestions = [
    'How would you rate the speaker\'s knowledge of the subject?',
    'How would you rate the speaker\'s presentation skills?',
    'How would you rate the quality of demos/examples?',
    'Did you learn what you expected from this session?'
  ];
  
  ratingQuestions.forEach(question => {
    form.addScaleItem()
      .setTitle(question)
      .setBounds(1, 5)
      .setLabels('Poor', 'Excellent')
      .setRequired(true);
  });
  
  // Add text questions
  form.addParagraphTextItem()
    .setTitle('What can the speaker do to improve?')
    .setHelpText('Please provide constructive feedback to help the speaker improve their presentation.')
    .setRequired(false);
    
  form.addParagraphTextItem()
    .setTitle('What did you like about the speaker and session?')
    .setHelpText('Please share what you found valuable or enjoyed about this session.')
    .setRequired(false);
  
  // Set form settings
  form.setCollectEmail(false);
  form.setLimitOneResponsePerUser(false);
  form.setShowLinkToRespondAgain(false);
  
  return form;
}

function createFormsFolder() {
  const folderName = 'SQL Saturday 2025 Feedback Forms';
  const folders = DriveApp.getFoldersByName(folderName);
  
  if (folders.hasNext()) {
    return folders.next().getId();
  } else {
    return DriveApp.createFolder(folderName).getId();
  }
}

function getSessionData() {
  // In a real implementation, you'd fetch from Sessionize API
  // For now, we'll use the data from your sessions.json
  
  // You can either:
  // 1. Copy-paste the session data here, or
  // 2. Upload sessions.json to Google Drive and read it
  
  // For this example, returning sample data structure:
  return [
    {
      title: "Sample Session Title",
      speakers: [{name: "Speaker Name"}],
      room: "Room Name",
      startsAt: "2025-07-25T09:00:00"
    }
    // Add your actual session data here
  ];
}

function exportResultsToSheet(results) {
  const sheet = SpreadsheetApp.create('SQL Saturday 2025 - Form Links');
  const worksheet = sheet.getActiveSheet();
  
  // Add headers
  worksheet.getRange(1, 1, 1, 5).setValues([
    ['Session Title', 'Speaker', 'Form URL', 'Edit URL', 'Status']
  ]);
  
  // Add data
  if (results.length > 0) {
    const data = results.map(r => [
      r.sessionTitle,
      r.speaker,
      r.formUrl,
      r.editUrl,
      r.status
    ]);
    
    worksheet.getRange(2, 1, data.length, 5).setValues(data);
  }
  
  // Format the sheet
  worksheet.getRange(1, 1, 1, 5).setFontWeight('bold');
  worksheet.autoResizeColumns(1, 5);
  
  console.log(`📊 Results exported to: ${sheet.getUrl()}`);
  return sheet.getUrl();
}

function testCreateOne() {
  // Test function to create just one form
  const testSession = {
    title: "Test Session - PowerShell Basics",
    speakers: [{name: "Test Speaker"}],
    room: "Test Room",
    startsAt: "2025-07-25T09:00:00"
  };
  
  const folderId = createFormsFolder();
  const form = createFeedbackForm(testSession, folderId);
  
  console.log(`Test form created: ${form.getPublishedUrl()}`);
  return form.getPublishedUrl();
}
```

### Step 3: Add Your Session Data

Replace the `getSessionData()` function with your actual session data, or modify it to read from your sessions.json file uploaded to Google Drive.

### Step 4: Run the Script

1. Click the "Run" button in Apps Script
2. Grant permissions when prompted
3. Check the logs for progress
4. Forms will be created in a "SQL Saturday 2025 Feedback Forms" folder in your Google Drive

## Advantages of This Approach

✅ **Actually works** - Apps Script can create forms
✅ **Easy to manage** - All forms in one folder
✅ **Bulk creation** - Can create all 51 forms at once  
✅ **Export links** - Automatically creates spreadsheet with all form URLs
✅ **No API limits** - No OAuth complications
✅ **Customizable** - Easy to modify form structure

## Next Steps

1. Set up the Apps Script project
2. Add your session data 
3. Run the script to create all forms
4. Export the form URLs and use them in your website generator

This will solve the 403 error issue completely!
