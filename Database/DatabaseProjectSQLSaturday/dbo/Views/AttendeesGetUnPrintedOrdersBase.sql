CREATE VIEW [dbo].[AttendeesGetUnPrintedOrdersBase]
AS
    SELECT
        TOP 100 PERCENT
        ROW_NUMBER() OVER (PARTITION BY
                               a.Email
                           ORDER BY
                               a.Email DESC
                          ) AS rownumber,
        a.[Order],
        a.Order_Date,
        a.Barcode,
        a.First_Name,
        a.Last_Name,
        a.Email,
        a.Lunch_Type,
        a.Attendee,
        a.Cell_Phone,
        ISNULL(   CASE
                      WHEN LEFT(a.Twitter_X_UserName, 1) <> '@'
                           AND LEFT(a.Twitter_X_UserName, 2) <> '''@' THEN
                          '@' + REPLACE(a.Twitter_X_UserName, 'https://twitter.com/', '')
                      WHEN LEFT(a.Twitter_X_UserName, 2) = '''@' THEN
                          REPLACE(a.Twitter_X_UserName, '''@', '@')
                      ELSE
                          a.Twitter_X_UserName
                  END, ''
              ) AS Twitter_Handle,
        a.LinkedIn_URL,
        a.Job_Title,
        a.Company,
        a.Website,
        a.Blog,
        CAST('BEGIN:VCARD
VERSION:3.0
N:' +   a.Last_Name + ';' + a.First_Name + ';;;
FN:' +  a.First_Name + ' ' + a.Last_Name + '
NICKNAME:' + ISNULL(   CASE
                           WHEN LEFT(a.Twitter_X_UserName, 1) <> '@'
                                AND LEFT(a.Twitter_X_UserName, 2) <> '''@' THEN
                               '@' + REPLACE(a.Twitter_X_UserName, 'https://twitter.com/', '')
                           WHEN LEFT(a.Twitter_X_UserName, 2) = '''@' THEN
                               REPLACE(a.Twitter_X_UserName, '''@', '@')
                           ELSE
                               a.Twitter_X_UserName
                       END, ''
                   ) + '
ORG:' + isnull(REPLACE(REPLACE(a.Company, ',', '\,'), '’', ''''),'') + ';
TITLE:' + ISNULL(a.Job_Title,'') + '
EMAIL;TYPE=WORK,INTERNET,pref:' + ISNULL(a.Email, '') + '
ADR;TYPE=WORK:;;' + '' + ';
URL;TYPE=WORK:' + ISNULL(a.Website, '') + '
URL:' + ISNULL(a.Blog, '') + '
NOTE;ENCODING=QUOTED-PRINTABLE:SQL Saturday Baton Rouge 2025 Contact'
        + CASE WHEN ISNULL(a.Job_Title, '') <> '' THEN ' | Job Title: ' + a.Job_Title ELSE '' END
        + CASE WHEN ISNULL(a.Twitter_X_UserName, '') <> '' THEN ' | Nickname: ' + 
            ISNULL(CASE
                WHEN LEFT(a.Twitter_X_UserName, 1) <> '@' AND LEFT(a.Twitter_X_UserName, 2) <> '''@' THEN
                    '@' + REPLACE(a.Twitter_X_UserName, 'https://twitter.com/', '')
                WHEN LEFT(a.Twitter_X_UserName, 2) = '''@' THEN
                    REPLACE(a.Twitter_X_UserName, '''@', '@')
                ELSE
                    a.Twitter_X_UserName
            END, '')
        ELSE '' END
        + '
END:VCARD
'       AS VARCHAR(MAX)) AS vCard
    FROM
        [dbo].[Attendees] AS a
    WHERE
        NOT EXISTS
        (
            SELECT
                1
            FROM
                dbo.AttendeesPrinted AS ap
            WHERE
                ap.[Barcode] = a.[Barcode]
        )
        --AND a.Total_Paid < 150.00
    ORDER BY
        a.Last_Name,
        a.First_Name;

GO

