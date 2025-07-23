import markdown2
from feedgen.feed import FeedGenerator
from datetime import datetime
import re
import zoneinfo

central = zoneinfo.ZoneInfo('America/Chicago')

with open('newsfeed.md', encoding='utf-8') as f:
    md = f.read()

# Parse markdown for news items (multiple updates per day supported)
sections = re.split(r'^## ', md, flags=re.MULTILINE)[1:]
items = []
for section in sections:
    lines = section.strip().splitlines()
    if not lines: continue
    date = lines[0].strip()
    for line in lines[1:]:
        line = line.strip()
        if line.startswith('- '):
            content = line[2:]
            items.append((date, content))

fg = FeedGenerator()
fg.title('SQL Saturday News')
fg.link(href='https://github.com/KennyNeal/SQL-Saturday-2025')
fg.description('Latest news and updates for SQL Saturday Baton Rouge 2025')

for date, content in items:
    fe = fg.add_entry()
    fe.title(content[:60])  # Use the update as the title (truncate if needed)
    fe.description(markdown2.markdown(content))
    try:
        pubdate = datetime.strptime(date, '%Y-%m-%d %H:%M').replace(tzinfo=central)
    except ValueError:
        pubdate = datetime.strptime(date, '%Y-%m-%d').replace(tzinfo=central)
    fe.pubDate(pubdate)

fg.rss_file('newsfeed.xml')
