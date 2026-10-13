#!/usr/bin/env python3
"""Create the stable feed with an immutable, versioned download URL."""
from pathlib import Path
import sys
import xml.etree.ElementTree as ET
from email.utils import formatdate

build, signature, dmg, output = sys.argv[1:]
if not build.isdecimal() or int(build) < 1:
    raise ValueError("Build number must be a positive integer")
version = f"1.0.{build}"
namespace = "http://www.andymatuschak.org/xml-namespaces/sparkle"
ET.register_namespace("sparkle", namespace)
feed = ET.Element("rss", version="2.0")
channel = ET.SubElement(feed, "channel")
ET.SubElement(channel, "title").text = "Snippets updates"
ET.SubElement(channel, "link").text = "https://github.com/EdmundLimBoEn/snippets/releases"
ET.SubElement(channel, "description").text = "Snippets for macOS"
ET.SubElement(channel, "language").text = "en"
item = ET.SubElement(channel, "item")
ET.SubElement(item, "title").text = f"Snippets {version}"
ET.SubElement(item, "pubDate").text = formatdate(usegmt=True)
ET.SubElement(item, f"{{{namespace}}}minimumSystemVersion").text = "26.0"
ET.SubElement(item, "enclosure", {
    "url": f"https://github.com/EdmundLimBoEn/snippets/releases/download/v{version}/Snippets.dmg",
    "length": str(Path(dmg).stat().st_size),
    "type": "application/octet-stream",
    f"{{{namespace}}}version": build,
    f"{{{namespace}}}shortVersionString": version,
    f"{{{namespace}}}edSignature": signature,
})
ET.indent(feed)
ET.ElementTree(feed).write(output, encoding="utf-8", xml_declaration=True)
