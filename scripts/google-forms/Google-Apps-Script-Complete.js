/**
 * Google Apps Script for Creating SQL Saturday 2025 Feedback Forms
 * Automatically fetches session data from Sessionize API and creates Google Forms
 */

// Configuration
const CONFIG = {
  sessionizeApiUrl: 'https://sessionize.com/api/v2/ta7h58rh/view/Sessions',
  folderName: 'SQL Saturday 2025 Feedback Forms',
  spreadsheetName: 'SQL Saturday 2025 - Form Links',
  
  // Form questions configuration
  ratingQuestions: [
    'How would you rate the speaker\'s knowledge of the subject?',
    'How would you rate the speaker\'s presentation skills?',
    'How would you rate the quality of demos/examples?',
    'Did you learn what you expected from this session?'
  ],
  
  textQuestions: [
    {
      title: 'What can the speaker do to improve?',
      helpText: 'Please provide constructive feedback to help the speaker improve their presentation.'
    },
    {
      title: 'What did you like about the speaker and session?',
      helpText: 'Please share what you found valuable or enjoyed about this session.'
    }
  ]
};

/**
 * Main function to create all session feedback forms
 */
function createSessionFeedbackForms() {
  try {
    console.log('🚀 Starting SQL Saturday 2025 form generation...');
    
    // Fetch session data from Sessionize API
    const sessions = fetchSessionData();
    console.log(`✓ Fetched ${sessions.length} valid sessions from Sessionize API`);
    
    // Create folder for forms
    const folderId = createFormsFolder();
    console.log(`✓ Created/found forms folder`);
    
    // Get existing forms to avoid duplicates
    const existingForms = getExistingForms(folderId);
    console.log(`📋 Found ${existingForms.length} existing forms in folder`);
    
    // Create forms for each session
    const results = [];
    let successCount = 0;
    let skippedCount = 0;
    
    sessions.forEach((session, index) => {
      try {
        const expectedFormTitle = `SQL Saturday 2025 - ${session.title} - Feedback`;
        
        // Check if form already exists
        const existingForm = existingForms.find(form => form.getName() === expectedFormTitle);
        if (existingForm) {
          console.log(`⏭️  Skipping ${index + 1}/${sessions.length}: ${session.title} (already exists)`);
          
          results.push({
            sessionTitle: session.title,
            speaker: session.speakers.map(s => s.name).join(', '),
            room: session.room,
            startTime: session.startsAt,
            formUrl: FormApp.openById(existingForm.getId()).getPublishedUrl(),
            editUrl: FormApp.openById(existingForm.getId()).getEditUrl(),
            status: 'Already Exists'
          });
          
          skippedCount++;
          return;
        }
        
        console.log(`Creating form ${index + 1}/${sessions.length}: ${session.title}`);
        
        const form = createFeedbackForm(session, folderId);
        
        results.push({
          sessionTitle: session.title,
          speaker: session.speakers.map(s => s.name).join(', '),
          room: session.room,
          startTime: session.startsAt,
          formUrl: form.getPublishedUrl(),
          editUrl: form.getEditUrl(),
          status: 'Created'
        });
        
        successCount++;
        console.log(`✓ Created form for: ${session.title}`);
        
        // Add small delay to avoid rate limiting
        Utilities.sleep(500);
        
      } catch (error) {
        console.error(`❌ Failed to create form for: ${session.title}`, error);
        results.push({
          sessionTitle: session.title,
          speaker: session.speakers.map(s => s.name).join(', '),
          room: session.room,
          startTime: session.startsAt,
          formUrl: 'ERROR',
          editUrl: 'ERROR',
          status: `Error: ${error.message}`
        });
      }
    });
    
    // Export results to spreadsheet
    const spreadsheetUrl = exportResultsToSheet(results);
    console.log(`📊 Results exported to: ${spreadsheetUrl}`);
    
    // Summary
    console.log(`\n🎉 Form generation completed!`);
    console.log(`✅ Successfully created: ${successCount} forms`);
    console.log(`⏭️  Skipped (already exist): ${skippedCount} forms`);
    console.log(`❌ Failed: ${results.length - successCount - skippedCount} forms`);
    console.log(`📋 Results spreadsheet: ${spreadsheetUrl}`);
    
    return {
      success: true,
      totalSessions: sessions.length,
      formsCreated: successCount,
      formsSkipped: skippedCount,
      formsFailed: results.length - successCount - skippedCount,
      results: results,
      spreadsheetUrl: spreadsheetUrl
    };
    
  } catch (error) {
    console.error('💥 Fatal error in form generation:', error);
    throw error;
  }
}

/**
 * Fetch session data from Sessionize API (with fallback to manual data)
 */
function fetchSessionData() {
  try {
    console.log(`📡 Attempting to fetch session data from: ${CONFIG.sessionizeApiUrl}`);
    
    const response = UrlFetchApp.fetch(CONFIG.sessionizeApiUrl, {
      method: 'GET',
      headers: {
        'Accept': 'application/json'
      },
      muteHttpExceptions: true
    });
    
    if (response.getResponseCode() !== 200) {
      throw new Error(`API request failed with status ${response.getResponseCode()}: ${response.getContentText()}`);
    }
    
    const data = JSON.parse(response.getContentText());
    console.log(`✓ Raw API response contains ${data.sessions.length} total sessions`);
    
    // Filter valid sessions (exclude service sessions, breaks, etc.)
    const validSessions = [];
    
    data.sessions.forEach(session => {
      // Skip service sessions and non-feedback sessions
      if (session.isServiceSession || 
          /Workshop|Lunch|Break|Registration|Keynote|Welcome|Closing/i.test(session.title) ||
          session.roomId === 20946 || session.roomId === 20947) {
        return;
      }
      
      // Create simplified session object
      validSessions.push({
        title: session.title,
        speakers: session.speakers || [],
        room: session.room,
        startsAt: session.startsAt,
        endsAt: session.endsAt,
        description: session.description
      });
    });
    
    console.log(`✓ Filtered to ${validSessions.length} valid sessions for feedback forms`);
    return validSessions;
    
  } catch (error) {
    console.error('❌ Error fetching session data from API:', error);
    console.log('🔄 Falling back to manual session data...');
    return getManualSessionData();
  }
}

/**
 * Manual session data fallback (in case API access is blocked)
 */
function getManualSessionData() {
  console.log('📋 Using manual session data...');
  
  // Complete session data for SQL Saturday 2025
  return [
    {
      title: "Hashing: The Cornerstone of Blockchain Security and Data Integrity",
      speakers: [{name: "James Davis"}],
      room: "Auditorium",
      startsAt: "2025-07-26T08:30:00"
    },
    {
      title: "Identify Poorly Performing Queries - Three Tools You Already Own",
      speakers: [{name: "Grant Fritchey"}],
      room: "Auditorium",
      startsAt: "2025-07-26T09:40:00"
    },
    {
      title: "PrAIctical Engineering",
      speakers: [{name: "Cory Murray"}, {name: "Bryan Fuselier"}],
      room: "Auditorium",
      startsAt: "2025-07-26T11:20:00"
    },
    {
      title: "Building Scalable Data Warehouses with Microsoft Fabric:",
      speakers: [{name: "Jonathan Stewart"}],
      room: "Auditorium",
      startsAt: "2025-07-26T13:40:00"
    },
    {
      title: "Common SQL Server Mistakes and How to Avoid Them",
      speakers: [{name: "Tim Radney"}],
      room: "Auditorium",
      startsAt: "2025-07-26T14:45:00"
    },
    {
      title: "How to Diagnose a Slow Power BI Report",
      speakers: [{name: "Jason Romans"}],
      room: "BEC 1220 (Analytics)",
      startsAt: "2025-07-26T08:30:00"
    },
    {
      title: "Applying Forensic Accounting Techniques using SQL and Python",
      speakers: [{name: "Kevin Feasel"}],
      room: "BEC 1220 (Analytics)",
      startsAt: "2025-07-26T09:40:00"
    },
    {
      title: "Mastering Microsoft Fabric Data Warehousing: Tips & Tricks You Need to Know",
      speakers: [{name: "Kristyna Ferris"}],
      room: "BEC 1220 (Analytics)",
      startsAt: "2025-07-26T11:20:00"
    },
    {
      title: "Cutting Through the Buzz: LLM, Agents, RAG, and GPT - Making Sense of Generative AI",
      speakers: [{name: "Doug Leal"}],
      room: "BEC 1220 (Analytics)",
      startsAt: "2025-07-26T13:40:00"
    },
    {
      title: "Unlocking Insights using Natural Language on Databricks Genie Spaces",
      speakers: [{name: "Srikanth Kumar Rana"}],
      room: "BEC 1220 (Analytics)",
      startsAt: "2025-07-26T14:45:00"
    },
    {
      title: "Leadership Principles Uncovered...",
      speakers: [{name: "Warren Sifre"}],
      room: "BEC 1225 (Professional Development)",
      startsAt: "2025-07-26T08:30:00"
    },
    {
      title: "How to Manage Recruiters and Hiring Managers in the Job Search",
      speakers: [{name: "Ava McClain"}],
      room: "BEC 1225 (Professional Development)",
      startsAt: "2025-07-26T09:40:00"
    },
    {
      title: "Careers in IT Baton Rouge 2025",
      speakers: [{name: "Michael Viron"}],
      room: "BEC 1225 (Professional Development)",
      startsAt: "2025-07-26T11:20:00"
    },
    {
      title: "Röck Yoür Cäreer: Time-Tested Wisdom from a 30-Year Software Engineering Veteran",
      speakers: [{name: "David McCarter"}],
      room: "BEC 1225 (Professional Development)",
      startsAt: "2025-07-26T13:40:00"
    },
    {
      title: "Tales from the SWAMP: Navigating the Murky Waters of Project Management",
      speakers: [{name: "Tanya Boyd"}],
      room: "BEC 1225 (Professional Development)",
      startsAt: "2025-07-26T14:45:00"
    },
    {
      title: "Mastering PowerShell Functions and Script Modules: Build, Reuse, and Share Your Code Like a Pro",
      speakers: [{name: "Mike Robbins"}],
      room: "BEC 1305 (PowerShell/Automation)",
      startsAt: "2025-07-26T08:30:00"
    },
    {
      title: "Extending Power BI with Power Automate",
      speakers: [{name: "Dominick Raimato"}],
      room: "BEC 1305 (PowerShell/Automation)",
      startsAt: "2025-07-26T09:40:00"
    },
    {
      title: "Don't Bash PowerShell",
      speakers: [{name: "Steven Judd"}],
      room: "BEC 1305 (PowerShell/Automation)",
      startsAt: "2025-07-26T11:20:00"
    },
    {
      title: "Getting Super Geeky with PowerShell Notebooks - It's Easy!",
      speakers: [{name: "Joe Houghes"}],
      room: "BEC 1305 (PowerShell/Automation)",
      startsAt: "2025-07-26T13:40:00"
    },
    {
      title: "Mastering Cursor: We're All Cooked (But in a Good Way)",
      speakers: [{name: "Brian Davis"}],
      room: "BEC 1305 (PowerShell/Automation)",
      startsAt: "2025-07-26T14:45:00"
    },
    {
      title: "Rapid Prototyping in the Age of AI",
      speakers: [{name: "Tommy Parrish"}],
      room: "BEC 1325 (.NET Development)",
      startsAt: "2025-07-26T08:30:00"
    },
    {
      title: "Learn the basics of Git and GitHub workflow",
      speakers: [{name: "Sean Wheeler"}],
      room: "BEC 1325 (.NET Development)",
      startsAt: "2025-07-26T09:40:00"
    },
    {
      title: "The Developer Testing Toolbox",
      speakers: [{name: "Jeremy Knight"}],
      room: "BEC 1325 (.NET Development)",
      startsAt: "2025-07-26T11:20:00"
    },
    {
      title: "Intro to Angular",
      speakers: [{name: "Ryan Richard"}],
      room: "BEC 1325 (.NET Development)",
      startsAt: "2025-07-26T13:40:00"
    },
    {
      title: "SQL Server Configuration Best Practices",
      speakers: [{name: "Ben Miller"}],
      room: "BEC 1325 (.NET Development)",
      startsAt: "2025-07-26T14:45:00"
    },
    {
      title: "Business Continuity in Azure SQL Databases",
      speakers: [{name: "John Deardurff"}],
      room: "BEC 1409 (Cloud)",
      startsAt: "2025-07-26T08:30:00"
    },
    {
      title: "Microsoft Fabric and Azure Health Data Services",
      speakers: [{name: "Jared Rhodes"}],
      room: "BEC 1409 (Cloud)",
      startsAt: "2025-07-26T09:40:00"
    },
    {
      title: "The Rise of AI Agents: What You Need to Know",
      speakers: [{name: "Muralidhar Chouhan"}],
      room: "BEC 1409 (Cloud)",
      startsAt: "2025-07-26T11:20:00"
    },
    {
      title: "SQL Server Hosting on AWS: Options and Considerations",
      speakers: [{name: "Alvaro Costa-Neto"}, {name: "Chetan Nandikanti"}],
      room: "BEC 1409 (Cloud)",
      startsAt: "2025-07-26T13:40:00"
    },
    {
      title: "Managing SQL Server with Azure Arc Unleashed",
      speakers: [{name: "David Pless"}, {name: "Abdullah Mamun"}],
      room: "BEC 1409 (Cloud)",
      startsAt: "2025-07-26T14:45:00"
    },
    {
      title: "The Collision of Real-Time Analytics and Observability",
      speakers: [{name: "Barkha Herman"}],
      room: "BEC 1425 (Cloud 2)",
      startsAt: "2025-07-26T08:30:00"
    },
    {
      title: "Using Digital Forensics for Data Loss Prevention (DLP)",
      speakers: [{name: "Paresh Motiwala"}],
      room: "BEC 1425 (Cloud 2)",
      startsAt: "2025-07-26T09:40:00"
    },
    {
      title: "Automate Your Documentation with Local AI",
      speakers: [{name: "Ian Trimble"}],
      room: "BEC 1425 (Cloud 2)",
      startsAt: "2025-07-26T11:20:00"
    },
    {
      title: "Connecting Power BI to API using POST",
      speakers: [{name: "Russel Loski"}],
      room: "BEC 1425 (Cloud 2)",
      startsAt: "2025-07-26T13:40:00"
    },
    {
      title: "Secure Communication Protocol for Distributed Environments",
      speakers: [{name: "Sravanthi Akavaram"}],
      room: "BEC 1425 (Cloud 2)",
      startsAt: "2025-07-26T14:00:00"
    },
    {
      title: "Squeezing the Apple for All Its Juice",
      speakers: [{name: "Mike Sammartino"}],
      room: "BEC 1425 (Cloud 2)",
      startsAt: "2025-07-26T14:20:00"
    },
    {
      title: "Who Needs a Warehouse When You've Got a Lakehouse?",
      speakers: [{name: "Nilanjan Chatterjee"}],
      room: "BEC 1425 (Cloud 2)",
      startsAt: "2025-07-26T14:45:00"
    },
    {
      title: "Getting Started Getting Started with Containerization",
      speakers: [{name: "Garo Yeriazarian"}],
      room: "BEC 1425 (Cloud 2)",
      startsAt: "2025-07-26T15:05:00"
    },
    {
      title: "Agentic AI in Construction – Transforming the Industry with Intelligent Solutions",
      speakers: [{name: "Dr. Srikanth Bangaru"}],
      room: "BEC 1425 (Cloud 2)",
      startsAt: "2025-07-26T15:25:00"
    },
    {
      title: "High speed failover Clustering with RDMA/ROCE with Hyper-v over converged multigigabit networks",
      speakers: [{name: "Christopher Long"}],
      room: "BEC 1920 (Security)",
      startsAt: "2025-07-26T08:30:00"
    },
    {
      title: "Strength in Partnerships: Cybersecurity and the Value of Vendor Management",
      speakers: [{name: "Rachel Arnold"}],
      room: "BEC 1920 (Security)",
      startsAt: "2025-07-26T09:40:00"
    },
    {
      title: "SQL Server 2025: an enterprise AI-ready database platform",
      speakers: [{name: "Ben Miller"}],
      room: "BEC 1920 (Security)",
      startsAt: "2025-07-26T11:20:00"
    },
    {
      title: "Let's Hack a Database",
      speakers: [{name: "Miguel Solis"}],
      room: "BEC 1920 (Security)",
      startsAt: "2025-07-26T13:40:00"
    },
    {
      title: "Narrative as a Design Tool",
      speakers: [{name: "Ricky Tucker"}],
      room: "BEC 1920 (Security)",
      startsAt: "2025-07-26T14:45:00"
    },
    {
      title: "Streamlining DataOps in Fabric: Implementing Azure DevOps CI/CD Pipelines for Fabric SQL DB",
      speakers: [{name: "Kevin Pereira"}],
      room: "BEC 2520 (SQL Server Development)",
      startsAt: "2025-07-26T08:30:00"
    },
    {
      title: "Modeling Software Development Problems in Time and Thinking Temporally",
      speakers: [{name: "Calvin Fabre"}],
      room: "BEC 2520 (SQL Server Development)",
      startsAt: "2025-07-26T09:40:00"
    },
    {
      title: "README.md? We Can Do Better!",
      speakers: [{name: "George Mauer"}],
      room: "BEC 2520 (SQL Server Development)",
      startsAt: "2025-07-26T11:20:00"
    },
    {
      title: "Natural Language Queries with ASP.NET",
      speakers: [{name: "Glenn Rumfellow"}],
      room: "BEC 2520 (SQL Server Development)",
      startsAt: "2025-07-26T13:40:00"
    },
    {
      title: "The T-SQL JSON Operators",
      speakers: [{name: "Jeff Foushee"}],
      room: "BEC 2520 (SQL Server Development)",
      startsAt: "2025-07-26T14:45:00"
    },
    {
      title: "Become immediately effective with PowerShell",
      speakers: [{name: "Sean Wheeler"}],
      room: "LA Tech Park 1",
      startsAt: "2025-07-25T08:00:00"
    },
    {
      title: "Jumpstart Your Power BI Skills: A Handson Workshop",
      speakers: [{name: "Russel Loski"}],
      room: "LA Tech Park 2",
      startsAt: "2025-07-25T08:00:00"
    }
  ];
}

/**
 * Create a feedback form for a single session
 */
function createFeedbackForm(session, folderId) {
  // Create the form
  const formTitle = `SQL Saturday 2025 - ${session.title} - Feedback`;
  const form = FormApp.create(formTitle);
  
  // Move to designated folder
  const file = DriveApp.getFileById(form.getId());
  DriveApp.getFolderById(folderId).addFile(file);
  DriveApp.getRootFolder().removeFile(file);
  
  // Set description
  const speakerNames = session.speakers.map(s => s.name).join(', ');
  const sessionTime = session.startsAt ? 
    new Date(session.startsAt).toLocaleString() : 'TBD';
  
  form.setDescription(
    `Session: ${session.title}\n` +
    `Speaker(s): ${speakerNames}\n` +
    `Time: ${sessionTime}\n` +
    `Room: ${session.room}\n\n` +
    `Your feedback helps speakers improve and helps us plan better events!\n` +
    `Please rate the session and provide your thoughts.`
  );
  
  // Add rating questions (1-5 scale)
  CONFIG.ratingQuestions.forEach(question => {
    form.addScaleItem()
      .setTitle(question)
      .setBounds(1, 5)
      .setLabels('Poor', 'Excellent')
      .setRequired(true);
  });
  
  // Add text questions
  CONFIG.textQuestions.forEach(question => {
    form.addParagraphTextItem()
      .setTitle(question.title)
      .setHelpText(question.helpText)
      .setRequired(false);
  });
  
  // Set form settings
  form.setCollectEmail(false);
  form.setLimitOneResponsePerUser(false);
  form.setShowLinkToRespondAgain(false);
  form.setAcceptingResponses(true);
  
  return form;
}

/**
 * Create or find the forms folder in Google Drive
 */
function createFormsFolder() {
  const folders = DriveApp.getFoldersByName(CONFIG.folderName);
  
  if (folders.hasNext()) {
    return folders.next().getId();
  } else {
    return DriveApp.createFolder(CONFIG.folderName).getId();
  }
}

/**
 * Get list of existing forms in the folder to avoid duplicates
 */
function getExistingForms(folderId) {
  try {
    const folder = DriveApp.getFolderById(folderId);
    const files = folder.getFilesByType(MimeType.GOOGLE_FORMS);
    const forms = [];
    
    while (files.hasNext()) {
      forms.push(files.next());
    }
    
    return forms;
  } catch (error) {
    console.warn('Warning: Could not get existing forms, proceeding anyway:', error);
    return [];
  }
}

/**
 * Export results to Google Sheets
 */
function exportResultsToSheet(results) {
  // Create new spreadsheet
  const sheet = SpreadsheetApp.create(CONFIG.spreadsheetName);
  const worksheet = sheet.getActiveSheet();
  worksheet.setName('Form Links');
  
  // Add headers
  const headers = ['Session Title', 'Speaker(s)', 'Room', 'Start Time', 'Form URL', 'Edit URL', 'Status'];
  worksheet.getRange(1, 1, 1, headers.length).setValues([headers]);
  
  // Add data
  if (results.length > 0) {
    const data = results.map(r => [
      r.sessionTitle,
      r.speaker,
      r.room,
      r.startTime,
      r.formUrl,
      r.editUrl,
      r.status
    ]);
    
    worksheet.getRange(2, 1, data.length, headers.length).setValues(data);
  }
  
  // Format the sheet
  worksheet.getRange(1, 1, 1, headers.length)
    .setFontWeight('bold')
    .setBackground('#4285f4')
    .setFontColor('white');
  
  // Auto-resize columns
  for (let i = 1; i <= headers.length; i++) {
    worksheet.autoResizeColumn(i);
  }
  
  // Add filter
  worksheet.getRange(1, 1, results.length + 1, headers.length).createFilter();
  
  // Add summary sheet
  const summarySheet = sheet.insertSheet('Summary');
  const successCount = results.filter(r => r.status === 'Created').length;
  const failureCount = results.length - successCount;
  
  summarySheet.getRange('A1:B6').setValues([
    ['SQL Saturday 2025 - Form Generation Summary', ''],
    ['Generated on:', new Date().toLocaleString()],
    ['Total sessions:', results.length],
    ['Forms created successfully:', successCount],
    ['Forms failed:', failureCount],
    ['Success rate:', `${Math.round((successCount / results.length) * 100)}%`]
  ]);
  
  summarySheet.getRange('A1').setFontWeight('bold').setFontSize(14);
  summarySheet.getRange('A2:A6').setFontWeight('bold');
  
  console.log(`📊 Results exported to: ${sheet.getUrl()}`);
  return sheet.getUrl();
}

/**
 * Test function to create just one form (for testing)
 */
function testCreateOneForm() {
  try {
    console.log('🧪 Testing form creation with one session...');
    
    // Get just the first session
    const allSessions = fetchSessionData();
    if (allSessions.length === 0) {
      throw new Error('No sessions found');
    }
    
    const testSession = allSessions[0];
    console.log(`Testing with session: ${testSession.title}`);
    
    const folderId = createFormsFolder();
    const form = createFeedbackForm(testSession, folderId);
    
    console.log(`✅ Test form created successfully!`);
    console.log(`📝 Form URL: ${form.getPublishedUrl()}`);
    console.log(`✏️  Edit URL: ${form.getEditUrl()}`);
    
    return {
      success: true,
      formUrl: form.getPublishedUrl(),
      editUrl: form.getEditUrl(),
      session: testSession
    };
    
  } catch (error) {
    console.error('❌ Test failed:', error);
    throw error;
  }
}

/**
 * Utility function to get session count from API
 */
function getSessionCount() {
  const sessions = fetchSessionData();
  console.log(`📊 Found ${sessions.length} sessions that need feedback forms`);
  
  // Group by room for summary
  const roomCounts = {};
  sessions.forEach(session => {
    roomCounts[session.room] = (roomCounts[session.room] || 0) + 1;
  });
  
  console.log('📍 Sessions by room:');
  Object.entries(roomCounts).forEach(([room, count]) => {
    console.log(`   ${room}: ${count} sessions`);
  });
  
  return sessions.length;
}
