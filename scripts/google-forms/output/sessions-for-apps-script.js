/**
 * Manual session data fallback (in case API access is blocked)
 * This replaces the getManualSessionData() function in Google Apps Script
 */
function getManualSessionData() {
  console.log('📋 Using manual session data...');
  
  // Complete session data for SQL Saturday 2025
  return [
    {
      title: "Hashing: The Cornerstone of Blockchain Security and Data Integrity",
      speakers: [{name: "James Davis"}],
      room: "Auditorium",
      startsAt: "07/26/2025 08:30:00"
    },
    {
      title: "Identify Poorly Performing Queries - Three Tools You Already Own",
      speakers: [{name: "Grant Fritchey"}],
      room: "Auditorium",
      startsAt: "07/26/2025 09:40:00"
    },
    {
      title: "PrAIctical Engineering",
      speakers: [{name: "Cory Murray"}, {name: "Bryan Fuselier"}],
      room: "Auditorium",
      startsAt: "07/26/2025 11:20:00"
    },
    {
      title: "Building Scalable Data Warehouses with Microsoft Fabric:",
      speakers: [{name: "Jonathan Stewart"}],
      room: "Auditorium",
      startsAt: "07/26/2025 13:40:00"
    },
    {
      title: "Common SQL Server Mistakes and How to Avoid Them",
      speakers: [{name: "Tim Radney"}],
      room: "Auditorium",
      startsAt: "07/26/2025 14:45:00"
    },
    {
      title: "How to Diagnose a Slow Power BI Report",
      speakers: [{name: "Jason Romans"}],
      room: "BEC 1220 (Analytics)",
      startsAt: "07/26/2025 08:30:00"
    },
    {
      title: "Applying Forensic Accounting Techniques using SQL and Python",
      speakers: [{name: "Kevin Feasel"}],
      room: "BEC 1220 (Analytics)",
      startsAt: "07/26/2025 09:40:00"
    },
    {
      title: "Mastering Microsoft Fabric Data Warehousing: Tips & Tricks You Need to Know",
      speakers: [{name: "Kristyna Ferris"}],
      room: "BEC 1220 (Analytics)",
      startsAt: "07/26/2025 11:20:00"
    },
    {
      title: "Cutting Through the Buzz: LLM, Agents, RAG, and GPT - Making Sense of Generative AI",
      speakers: [{name: "Doug Leal"}],
      room: "BEC 1220 (Analytics)",
      startsAt: "07/26/2025 13:40:00"
    },
    {
      title: "Unlocking Insights using Natural Language on Databricks Genie Spaces",
      speakers: [{name: "Srikanth Kumar Rana"}],
      room: "BEC 1220 (Analytics)",
      startsAt: "07/26/2025 14:45:00"
    },
    {
      title: "Leadership Principles Uncovered...",
      speakers: [{name: "Warren Sifre"}],
      room: "BEC 1225 (Professional Development)",
      startsAt: "07/26/2025 08:30:00"
    },
    {
      title: "How to Manage Recruiters and Hiring Managers in the Job Search",
      speakers: [{name: "Ava McClain"}],
      room: "BEC 1225 (Professional Development)",
      startsAt: "07/26/2025 09:40:00"
    },
    {
      title: "Careers in IT Baton Rouge 2025",
      speakers: [{name: "Michael Viron"}],
      room: "BEC 1225 (Professional Development)",
      startsAt: "07/26/2025 11:20:00"
    },
    {
      title: "Röck Yoür Cäreer: Time-Tested Wisdom from a 30-Year Software Engineering Veteran",
      speakers: [{name: "David McCarter"}],
      room: "BEC 1225 (Professional Development)",
      startsAt: "07/26/2025 13:40:00"
    },
    {
      title: "Tales from the SWAMP: Navigating the Murky Waters of Project Management",
      speakers: [{name: "Tanya Boyd"}],
      room: "BEC 1225 (Professional Development)",
      startsAt: "07/26/2025 14:45:00"
    },
    {
      title: "Mastering PowerShell Functions and Script Modules: Build, Reuse, and Share Your Code Like a Pro",
      speakers: [{name: "Mike Robbins"}],
      room: "BEC 1305 (PowerShell/Automation)",
      startsAt: "07/26/2025 08:30:00"
    },
    {
      title: "Extending Power BI with Power Automate",
      speakers: [{name: "Dominick Raimato"}],
      room: "BEC 1305 (PowerShell/Automation)",
      startsAt: "07/26/2025 09:40:00"
    },
    {
      title: "Don't Bash PowerShell",
      speakers: [{name: "Steven Judd"}],
      room: "BEC 1305 (PowerShell/Automation)",
      startsAt: "07/26/2025 11:20:00"
    },
    {
      title: "Getting Super Geeky with PowerShell Notebooks - It's Easy!",
      speakers: [{name: "Joe Houghes"}],
      room: "BEC 1305 (PowerShell/Automation)",
      startsAt: "07/26/2025 13:40:00"
    },
    {
      title: "Mastering Cursor: We're All Cooked (But in a Good Way)",
      speakers: [{name: "Brian Davis"}],
      room: "BEC 1305 (PowerShell/Automation)",
      startsAt: "07/26/2025 14:45:00"
    },
    {
      title: "Rapid Prototyping in the Age of AI",
      speakers: [{name: "Tommy Parrish"}],
      room: "BEC 1325 (.NET Development)",
      startsAt: "07/26/2025 08:30:00"
    },
    {
      title: "Learn the basics of Git and GitHub workflow",
      speakers: [{name: "Sean Wheeler"}],
      room: "BEC 1325 (.NET Development)",
      startsAt: "07/26/2025 09:40:00"
    },
    {
      title: "The Developer Testing Toolbox",
      speakers: [{name: "Jeremy Knight"}],
      room: "BEC 1325 (.NET Development)",
      startsAt: "07/26/2025 11:20:00"
    },
    {
      title: "Intro to Angular",
      speakers: [{name: "Ryan Richard"}],
      room: "BEC 1325 (.NET Development)",
      startsAt: "07/26/2025 13:40:00"
    },
    {
      title: "SQL Server Configuration Best Practices",
      speakers: [{name: "Ben Miller"}],
      room: "BEC 1325 (.NET Development)",
      startsAt: "07/26/2025 14:45:00"
    },
    {
      title: "Business Continuity in Azure SQL Databases",
      speakers: [{name: "John Deardurff"}],
      room: "BEC 1409 (Cloud)",
      startsAt: "07/26/2025 08:30:00"
    },
    {
      title: "Microsoft Fabric and Azure Health Data Services",
      speakers: [{name: "Jared Rhodes"}],
      room: "BEC 1409 (Cloud)",
      startsAt: "07/26/2025 09:40:00"
    },
    {
      title: "The Rise of AI Agents: What You Need to Know",
      speakers: [{name: "Muralidhar Chouhan"}],
      room: "BEC 1409 (Cloud)",
      startsAt: "07/26/2025 11:20:00"
    },
    {
      title: "SQL Server Hosting on AWS: Options and Considerations",
      speakers: [{name: "Alvaro Costa-Neto"}, {name: "Chetan Nandikanti"}],
      room: "BEC 1409 (Cloud)",
      startsAt: "07/26/2025 13:40:00"
    },
    {
      title: "Managing SQL Server with Azure Arc Unleashed",
      speakers: [{name: "David Pless"}, {name: "Abdullah Mamun"}],
      room: "BEC 1409 (Cloud)",
      startsAt: "07/26/2025 14:45:00"
    },
    {
      title: "The Collision of Real-Time Analytics and Observability",
      speakers: [{name: "Barkha Herman"}],
      room: "BEC 1425 (Cloud 2)",
      startsAt: "07/26/2025 08:30:00"
    },
    {
      title: "Using Digital Forensics for Data Loss Prevention (DLP)",
      speakers: [{name: "Paresh Motiwala"}],
      room: "BEC 1425 (Cloud 2)",
      startsAt: "07/26/2025 09:40:00"
    },
    {
      title: "Automate Your Documentation with Local AI",
      speakers: [{name: "Ian Trimble"}],
      room: "BEC 1425 (Cloud 2)",
      startsAt: "07/26/2025 11:20:00"
    },
    {
      title: "Connecting Power BI to API using POST",
      speakers: [{name: "Russel Loski"}],
      room: "BEC 1425 (Cloud 2)",
      startsAt: "07/26/2025 13:40:00"
    },
    {
      title: "Secure Communication Protocol for Distributed Environments",
      speakers: [{name: "Sravanthi Akavaram"}],
      room: "BEC 1425 (Cloud 2)",
      startsAt: "07/26/2025 14:00:00"
    },
    {
      title: "Squeezing the Apple for All Its Juice",
      speakers: [{name: "Mike Sammartino"}],
      room: "BEC 1425 (Cloud 2)",
      startsAt: "07/26/2025 14:20:00"
    },
    {
      title: "Who Needs a Warehouse When You've Got a Lakehouse?",
      speakers: [{name: "Nilanjan Chatterjee"}],
      room: "BEC 1425 (Cloud 2)",
      startsAt: "07/26/2025 14:45:00"
    },
    {
      title: "Getting Started Getting Started with Containerization",
      speakers: [{name: "Garo Yeriazarian"}],
      room: "BEC 1425 (Cloud 2)",
      startsAt: "07/26/2025 15:05:00"
    },
    {
      title: "Agentic AI in Construction – Transforming the Industry with Intelligent Solutions",
      speakers: [{name: "Dr. Srikanth Bangaru"}],
      room: "BEC 1425 (Cloud 2)",
      startsAt: "07/26/2025 15:25:00"
    },
    {
      title: "High speed failover Clustering with RDMA/ROCE with Hyper-v over converged multigigabit networks",
      speakers: [{name: "Christopher Long"}],
      room: "BEC 1920 (Security)",
      startsAt: "07/26/2025 08:30:00"
    },
    {
      title: "Strength in Partnerships: Cybersecurity and the Value of Vendor Management",
      speakers: [{name: "Rachel Arnold"}],
      room: "BEC 1920 (Security)",
      startsAt: "07/26/2025 09:40:00"
    },
    {
      title: "SQL Server 2025: an enterprise AI-ready database platform",
      speakers: [{name: "Ben Miller"}],
      room: "BEC 1920 (Security)",
      startsAt: "07/26/2025 11:20:00"
    },
    {
      title: "Let’s Hack a Database",
      speakers: [{name: "Miguel Solis"}],
      room: "BEC 1920 (Security)",
      startsAt: "07/26/2025 13:40:00"
    },
    {
      title: "Narrative as a Design Tool",
      speakers: [{name: "Ricky Tucker"}],
      room: "BEC 1920 (Security)",
      startsAt: "07/26/2025 14:45:00"
    },
    {
      title: "Streamlining DataOps in Fabric: Implementing Azure DevOps CI/CD Pipelines for Fabric SQL DB",
      speakers: [{name: "Kevin Pereira"}],
      room: "BEC 2520 (SQL Server Development)",
      startsAt: "07/26/2025 08:30:00"
    },
    {
      title: "Modeling Software Development Problems in Time and Thinking Temporally",
      speakers: [{name: "Calvin Fabre"}],
      room: "BEC 2520 (SQL Server Development)",
      startsAt: "07/26/2025 09:40:00"
    },
    {
      title: "README.md? We Can Do Better!",
      speakers: [{name: "George Mauer"}],
      room: "BEC 2520 (SQL Server Development)",
      startsAt: "07/26/2025 11:20:00"
    },
    {
      title: "Natural Language Queries with ASP.NET",
      speakers: [{name: "Glenn Rumfellow"}],
      room: "BEC 2520 (SQL Server Development)",
      startsAt: "07/26/2025 13:40:00"
    },
    {
      title: "The T-SQL JSON Operators",
      speakers: [{name: "Jeff Foushee"}],
      room: "BEC 2520 (SQL Server Development)",
      startsAt: "07/26/2025 14:45:00"
    },
    {
      title: "Become immediately effective with PowerShell",
      speakers: [{name: "Sean Wheeler"}],
      room: "LA Tech Park 1",
      startsAt: "07/25/2025 08:00:00"
    },
    {
      title: "Jumpstart Your Power BI Skills: A Handson Workshop",
      speakers: [{name: "Russel Loski"}],
      room: "LA Tech Park 2",
      startsAt: "07/25/2025 08:00:00"
    }
  ];
}
