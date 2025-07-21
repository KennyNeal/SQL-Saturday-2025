CREATE VIEW [dbo].[AttendeesWithVCard]
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
        'BEGIN:VCARD' + CHAR(13) + CHAR(10) +
        'VERSION:3.0' + CHAR(13) + CHAR(10) +
        'N:' + a.Last_Name + ';' + a.First_Name + ';;;' + CHAR(13) + CHAR(10) +
        'FN:' + a.First_Name + ' ' + a.Last_Name + CHAR(13) + CHAR(10) +
        'NICKNAME:' + ISNULL(   CASE
                                   WHEN LEFT(a.Twitter_X_UserName, 1) <> '@'
                                        AND LEFT(a.Twitter_X_UserName, 2) <> '''@' THEN
                                       '@' + REPLACE(a.Twitter_X_UserName, 'https://twitter.com/', '')
                                   WHEN LEFT(a.Twitter_X_UserName, 2) = '''@' THEN
                                       REPLACE(a.Twitter_X_UserName, '''@', '@')
                                   ELSE
                                       a.Twitter_X_UserName
                               END, ''
                           ) + CHAR(13) + CHAR(10) +
        'ORG:' + isnull(REPLACE(REPLACE(a.Company, ',', '\,'), '''', ''''),'') + CHAR(13) + CHAR(10) +
        'TITLE:' + ISNULL(a.Job_Title,'') + CHAR(13) + CHAR(10) +
        'EMAIL;TYPE=WORK,INTERNET,pref:' + ISNULL(a.Email, '') + CHAR(13) + CHAR(10) +
        'ADR;TYPE=WORK:;;' + '' + ';' + CHAR(13) + CHAR(10) +
        'URL;TYPE=WORK:' + ISNULL(a.Website, '') + CHAR(13) + CHAR(10) +
        'URL:' + ISNULL(a.Blog, '') + CHAR(13) + CHAR(10) +
        'NOTE;ENCODING=QUOTED-PRINTABLE:SQL Saturday Baton Rouge 2025 Contact' 
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
        + CHAR(13) + CHAR(10) +
        'END:VCARD' + CHAR(13) + CHAR(10) AS vCard
    FROM
        [dbo].[Attendees] AS a
    ORDER BY
        a.Last_Name,
        a.First_Name;

GO
