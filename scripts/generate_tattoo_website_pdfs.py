#!/usr/bin/env python3
"""Generate design PDF(s) for tattoo studio lean website mockups."""

from __future__ import annotations

STUDIO_NAME = "D5 Tattoo Studio"

import os
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm, mm
from reportlab.platypus import (
    Image,
    PageBreak,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
)

ASSETS = Path("/opt/cursor/artifacts/assets")
OUTPUT = Path("/opt/cursor/artifacts/pdfs")
OUTPUT.mkdir(parents=True, exist_ok=True)

PAGE_W, PAGE_H = landscape(A4)
MARGIN = 1.5 * cm
CONTENT_W = PAGE_W - 2 * MARGIN

GOLD = colors.HexColor("#C9A227")
CHARCOAL = colors.HexColor("#1A1A1A")
MUTED = colors.HexColor("#555555")


def styles():
    base = getSampleStyleSheet()
    return {
        "cover_title": ParagraphStyle(
            "cover_title",
            parent=base["Title"],
            fontSize=28,
            leading=34,
            textColor=CHARCOAL,
            alignment=TA_CENTER,
            spaceAfter=12,
        ),
        "cover_sub": ParagraphStyle(
            "cover_sub",
            parent=base["Normal"],
            fontSize=14,
            leading=18,
            textColor=MUTED,
            alignment=TA_CENTER,
            spaceAfter=8,
        ),
        "section": ParagraphStyle(
            "section",
            parent=base["Heading1"],
            fontSize=20,
            leading=24,
            textColor=CHARCOAL,
            spaceBefore=6,
            spaceAfter=10,
        ),
        "page_title": ParagraphStyle(
            "page_title",
            parent=base["Heading2"],
            fontSize=16,
            leading=20,
            textColor=GOLD,
            spaceBefore=4,
            spaceAfter=6,
        ),
        "body": ParagraphStyle(
            "body",
            parent=base["Normal"],
            fontSize=10,
            leading=14,
            textColor=CHARCOAL,
            spaceAfter=4,
        ),
        "bullet": ParagraphStyle(
            "bullet",
            parent=base["Normal"],
            fontSize=10,
            leading=14,
            textColor=CHARCOAL,
            leftIndent=14,
            bulletIndent=0,
            spaceAfter=3,
        ),
        "small": ParagraphStyle(
            "small",
            parent=base["Normal"],
            fontSize=8,
            leading=10,
            textColor=MUTED,
            alignment=TA_CENTER,
        ),
    }


def scaled_image(path: Path, max_w: float, max_h: float) -> Image:
    img = Image(str(path))
    iw, ih = img.imageWidth, img.imageHeight
    scale = min(max_w / iw, max_h / ih)
    img.drawWidth = iw * scale
    img.drawHeight = ih * scale
    return img


def bullet_block(items: list[str], st: dict) -> list:
    flow = []
    for item in items:
        flow.append(Paragraph(f"• {item}", st["bullet"]))
    return flow


def build_pdf(
    filename: str,
    cover_title: str,
    cover_sub: str,
    sections: list[dict],
    *,
    table_of_contents: list[str] | None = None,
):
    from reportlab.platypus import SimpleDocTemplate

    st = styles()
    path = OUTPUT / filename
    doc = SimpleDocTemplate(
        str(path),
        pagesize=landscape(A4),
        leftMargin=MARGIN,
        rightMargin=MARGIN,
        topMargin=MARGIN,
        bottomMargin=MARGIN,
        title=cover_title,
        author=f"{STUDIO_NAME} Website Design",
    )
    story = []

    # Cover
    story.append(Spacer(1, 2.2 * cm))
    story.append(Paragraph(cover_title, st["cover_title"]))
    story.append(Paragraph(cover_sub, st["cover_sub"]))
    story.append(Spacer(1, 0.4 * cm))
    story.append(Paragraph("Lean Website Design Pack · UI Mockups & Page Specifications", st["cover_sub"]))
    story.append(Spacer(1, 0.8 * cm))
    story.append(Paragraph("No pricing or commercial analysis included.", st["small"]))
    story.append(PageBreak())

    if table_of_contents:
        story.append(Paragraph("Contents", st["section"]))
        story.append(Spacer(1, 0.3 * cm))
        for line in table_of_contents:
            story.append(Paragraph(line, st["bullet"]))
        story.append(PageBreak())

    for section in sections:
        if section.get("type") == "overview":
            story.append(Paragraph(section["title"], st["section"]))
            story.append(Spacer(1, 0.2 * cm))
            for para in section.get("paragraphs", []):
                story.append(Paragraph(para, st["body"]))
            story.append(Spacer(1, 0.15 * cm))

            if "nav_table" in section:
                data = section["nav_table"]
                t = Table(data, colWidths=[4.5 * cm, 5.5 * cm, CONTENT_W - 10 * cm - 12])
                t.setStyle(
                    TableStyle(
                        [
                            ("BACKGROUND", (0, 0), (-1, 0), GOLD),
                            ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                            ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                            ("FONTSIZE", (0, 0), (-1, -1), 9),
                            ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F5F5F5")]),
                            ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#DDDDDD")),
                            ("VALIGN", (0, 0), (-1, -1), "TOP"),
                            ("LEFTPADDING", (0, 0), (-1, -1), 6),
                            ("RIGHTPADDING", (0, 0), (-1, -1), 6),
                            ("TOPPADDING", (0, 0), (-1, -1), 5),
                            ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
                        ]
                    )
                )
                story.append(t)

            if "flow_diagram" in section:
                story.append(Spacer(1, 0.25 * cm))
                story.append(Paragraph(section["flow_diagram"], st["body"]))

            story.append(PageBreak())
            continue

        # Mockup page spread
        story.append(Paragraph(section["title"], st["section"]))
        story.append(Paragraph(section["subtitle"], st["page_title"]))
        story.append(Spacer(1, 0.1 * cm))

        img_path = ASSETS / section["image"]
        if img_path.exists():
            # Two-column: image left, details right
            img = scaled_image(img_path, CONTENT_W * 0.58, PAGE_H - 4.5 * cm)
            details = []
            details.append(Paragraph("<b>Purpose</b>", st["body"]))
            details.append(Paragraph(section["purpose"], st["body"]))
            details.append(Spacer(1, 0.15 * cm))
            details.append(Paragraph("<b>Navigation</b>", st["body"]))
            details.extend(bullet_block(section["navigation"], st))
            details.append(Spacer(1, 0.15 * cm))
            details.append(Paragraph("<b>Key elements</b>", st["body"]))
            details.extend(bullet_block(section["elements"], st))
            if section.get("user_actions"):
                details.append(Spacer(1, 0.15 * cm))
                details.append(Paragraph("<b>User actions</b>", st["body"]))
                details.extend(bullet_block(section["user_actions"], st))
            if section.get("links_to"):
                details.append(Spacer(1, 0.15 * cm))
                details.append(Paragraph("<b>Links to</b>", st["body"]))
                details.extend(bullet_block(section["links_to"], st))

            from reportlab.platypus import KeepTogether

            row = Table([[img, details]], colWidths=[CONTENT_W * 0.58, CONTENT_W * 0.40])
            row.setStyle(
                TableStyle(
                    [
                        ("VALIGN", (0, 0), (-1, -1), "TOP"),
                        ("LEFTPADDING", (0, 0), (-1, -1), 0),
                        ("RIGHTPADDING", (0, 0), (-1, -1), 0),
                    ]
                )
            )
            story.append(row)
        else:
            story.append(Paragraph(f"Image not found: {section['image']}", st["body"]))

        story.append(PageBreak())

    doc.build(story)
    print(f"Created {path} ({path.stat().st_size // 1024} KB)")


NAV_TABLE = [
    ["Page", "URL slug", "Primary role"],
    ["Home", "/", "Brand entry, CTAs, trust signals"],
    ["Artists", "/artists", "Artist list → individual portfolios"],
    ["Artist profile", "/artists/{slug}", "Style match, book per artist"],
    ["Gallery", "/gallery", "Studio-wide filterable work"],
    ["Book", "/book", "Calendar, services, deposit"],
    ["Forms", "/book/forms", "Health + consent (pre-payment)"],
    ["Aftercare", "/aftercare", "Day-by-day healing guide"],
    ["FAQ", "/faq", "Policies, pricing approach, prep"],
    ["Privacy", "/privacy", "GDPR / data protection"],
    ["Cookies", "/cookies", "Cookie categories & consent"],
    ["Terms", "/terms", "Booking terms, liability"],
    ["Contact", "/contact", "Map, hours, directions"],
]

FLOW_TEXT = (
    "<b>Primary user flow:</b> Home → Artists or Gallery → Artist profile → Book → "
    "Health form → Consent & waiver → Deposit → Confirmation → Aftercare.<br/>"
    "<b>Footer on every page:</b> Privacy · Cookies · Terms · Data request · Contact"
)


PDF1_SECTIONS = [
    {
        "type": "overview",
        "title": "Part 1 — Site Overview & Navigation",
        "paragraphs": [
            "Lean tattoo studio website: discovery-first, booking-second, compliance built in.",
            "Primary navigation: <b>Home · Artists · Gallery · Book · Aftercare · FAQ · Contact</b>",
        ],
        "nav_table": NAV_TABLE,
        "flow_diagram": FLOW_TEXT,
    },
    {
        "title": "01 — Homepage",
        "subtitle": "Brand entry & conversion",
        "image": "tattoo-web-01-homepage.png",
        "purpose": "Convert Instagram and search traffic into artist browsing or direct booking.",
        "navigation": [
            "Top nav: Home, Artists, Gallery, Book, Forms, FAQ",
            "Hero CTAs: Browse Artists · Book Consultation",
            "Footer: Privacy, GDPR, Cookie notice",
        ],
        "elements": [
            "Hero with healed tattoo photography",
            "Three value pillars: Portfolio, Online Booking, Aftercare",
            "Featured artists strip (optional)",
            "Mobile-responsive hamburger nav",
        ],
        "user_actions": ["Browse artists", "Start booking", "Read aftercare"],
        "links_to": ["/artists", "/book", "/aftercare", "/privacy"],
    },
    {
        "title": "02 — Artist Portfolio",
        "subtitle": "Per-artist profile page",
        "image": "tattoo-web-02-artist-portfolio.png",
        "purpose": "Help clients match style to artist before committing to a consult or session.",
        "navigation": [
            "Breadcrumb: Artists / {Artist name}",
            "Book with {Artist} — primary CTA",
            "Back to all artists",
        ],
        "elements": [
            "Artist photo, bio, specialties, social link",
            "Portfolio grid: Fresh vs Healed labels",
            "Placement filters: Arms, Ribs, Floral, etc.",
            "Optional: availability snippet",
        ],
        "user_actions": ["Filter portfolio", "Save favourites (v2)", "Book this artist"],
        "links_to": ["/book?artist={slug}", "/gallery?style=fine-line"],
    },
    {
        "title": "03 — Gallery",
        "subtitle": "Studio-wide inspiration grid",
        "image": "tattoo-web-04-gallery.png",
        "purpose": "SEO, inspiration, and cross-artist discovery beyond individual profiles.",
        "navigation": [
            "Top nav → Gallery",
            "Click image → lightbox with artist credit",
            "Filter by style chip",
        ],
        "elements": [
            "Masonry or uniform grid",
            "Style filters: Fine Line, Traditional, Blackwork, Realism, Cover-up",
            "Sort: Newest · Healed work",
            "Lightbox: artist name, placement, link to artist page",
        ],
        "user_actions": ["Filter by style", "Open lightbox", "Go to artist profile"],
        "links_to": ["/artists/{slug}", "/book"],
    },
]

PDF2_SECTIONS = [
    {
        "type": "overview",
        "title": "Part 2 — Booking & Client Intake",
        "paragraphs": [
            "Booking flow is a guided wizard. Forms are completed <b>before</b> deposit payment.",
            "All form submissions are tied to the appointment record with timestamp and e-signature.",
        ],
        "nav_table": [
            ["Step", "Screen", "Notes"],
            ["1", "Choose artist", "Pre-selected if coming from profile"],
            ["2", "Select service", "Consult · Half day · Full day"],
            ["3", "Pick date & time", "Per-artist calendar"],
            ["4", "Health questionnaire", "Allergies, conditions, pregnancy"],
            ["5", "Consent & waiver", "E-sign + policy acknowledgement"],
            ["6", "Photo consent", "Separate from medical waiver"],
            ["7", "Deposit payment", "Razorpay / card / UPI"],
            ["8", "Confirmation", "Email + SMS + aftercare link"],
        ],
    },
    {
        "title": "04 — Online Booking",
        "subtitle": "Calendar, services & deposit",
        "image": "tattoo-web-03-booking.png",
        "purpose": "Replace DM booking with structured slots, clear pricing approach, and deposit collection.",
        "navigation": [
            "Entry: Nav → Book, or CTA from artist page",
            "Step indicator: 1 Choose Artist → 2 Service → 3 Date",
            "Sidebar: live booking summary",
        ],
        "elements": [
            "Artist cards with avatar",
            "Service types with duration: Consult 30m, Half 2h, Full 6h",
            "Calendar with available slots highlighted",
            "Deposit amount + cancellation policy link",
            "Razorpay checkout embed",
        ],
        "user_actions": ["Select artist", "Pick service & slot", "Review policy", "Pay deposit"],
        "links_to": ["/book/forms", "/faq#cancellation", "/terms"],
    },
    {
        "title": "05 — Consent & Health Forms",
        "subtitle": "Pre-appointment digital intake",
        "image": "tattoo-web-05-consent-forms.png",
        "purpose": "Medical screening and legal waiver before the session; reduces paper on arrival.",
        "navigation": [
            "Reached after slot selection, before payment",
            "Progress: Step 2 of 3 (Forms)",
            "Back preserves entered data",
        ],
        "elements": [
            "Health questionnaire: allergies, pregnancy, blood thinners, skin conditions",
            "Tattoo consent & waiver with scrollable legal text",
            "E-signature pad + timestamp",
            "GDPR notice: retention, delete request link",
            "Checkbox: I agree to Privacy Policy",
        ],
        "user_actions": ["Complete health form", "Sign waiver", "Accept privacy terms", "Continue to payment"],
        "links_to": ["/privacy", "/terms", "Data request form"],
    },
]

PDF3_SECTIONS = [
    {
        "type": "overview",
        "title": "Part 3 — Trust, Care & Policies",
        "paragraphs": [
            "Post-booking care and legal pages build trust and reduce support load.",
            "These pages are linked from confirmation emails, footer, and the booking flow.",
        ],
        "nav_table": [
            ["Page", "When client sees it", "Studio benefit"],
            ["Aftercare", "After booking + day 1–14 emails", "Fewer healing DMs"],
            ["FAQ", "Before booking", "Sets expectations"],
            ["Cancellation", "During booking + FAQ", "Fewer disputes"],
            ["Privacy", "Forms + footer", "GDPR / DPDP compliance"],
            ["Cookies", "First visit banner", "Analytics consent"],
        ],
    },
    {
        "title": "06 — Aftercare Guide",
        "subtitle": "Day-by-day healing timeline",
        "image": "tattoo-web-07-aftercare.png",
        "purpose": "Guide clients through healing; flag when to contact the studio.",
        "navigation": [
            "Nav → Aftercare",
            "Linked from booking confirmation email/SMS",
            "Day 1–14 sidebar navigation",
        ],
        "elements": [
            "Timeline: Day 1 through Day 14",
            "Daily checklist: wash, dry, balm, restrictions",
            "Warning card: normal vs contact studio",
            "Download PDF option",
            "Approved products list",
        ],
        "user_actions": ["Browse by day", "Download PDF", "Contact studio if concerned"],
        "links_to": ["/contact", "/faq#healing"],
    },
    {
        "title": "07 — FAQ & Cancellation Policy",
        "subtitle": "Expectations before booking",
        "image": "tattoo-web-08-faq-cancellation.png",
        "purpose": "Answer common questions and surface cancellation rules before deposit is paid.",
        "navigation": [
            "Nav → FAQ",
            "Linked from booking sidebar",
            "Accordion sections for scanability",
        ],
        "elements": [
            "FAQ: pricing approach, walk-ins, deposits, session prep",
            "Highlighted cancellation card: 48h reschedule, no-show policy",
            "Late arrival rules",
            "Link to full Terms of Service",
        ],
        "user_actions": ["Expand FAQ items", "Read policy before paying deposit"],
        "links_to": ["/terms", "/book", "/contact"],
    },
    {
        "title": "08 — Privacy & GDPR",
        "subtitle": "Data protection & cookie compliance",
        "image": "tattoo-web-06-privacy-gdpr.png",
        "purpose": "Legal transparency for personal and health data collected via forms and booking.",
        "navigation": [
            "Footer → Privacy on every page",
            "Linked from consent forms",
            "Cookie banner → Cookie Policy",
        ],
        "elements": [
            "What we collect · How we use it · Legal basis",
            "Retention period (e.g. 7 years for waivers)",
            "Your rights: access, delete, portability",
            "Cookie categories: Essential · Analytics · Marketing",
            "Contact / DPO email · Data request form",
        ],
        "user_actions": ["Read policy", "Submit data request", "Manage cookie preferences"],
        "links_to": ["/cookies", "/terms", "Data request form"],
    },
]


COMBINED_TOC = [
    "Site overview & navigation",
    "01 — Homepage",
    "02 — Artist portfolio",
    "03 — Gallery",
    "Booking flow overview",
    "04 — Online booking",
    "05 — Consent & health forms",
    "Trust, care & policies overview",
    "06 — Aftercare guide",
    "07 — FAQ & cancellation policy",
    "08 — Privacy & GDPR",
]


def main():
    combined = (
        PDF1_SECTIONS
        + PDF2_SECTIONS
        + PDF3_SECTIONS
    )
    safe_name = STUDIO_NAME.replace(" ", "-")
    build_pdf(
        f"{safe_name}-Website-Design-Complete.pdf",
        STUDIO_NAME,
        "Lean Website — UI Mockups, Navigation & Page Specifications",
        combined,
        table_of_contents=COMBINED_TOC,
    )
    # Copy to workspace
    workspace_out = Path("/workspace/docs/tattoo-website-mockups")
    workspace_out.mkdir(parents=True, exist_ok=True)
    import shutil

    src = OUTPUT / f"{safe_name}-Website-Design-Complete.pdf"
    dst = workspace_out / f"{safe_name}-Website-Design-Complete.pdf"
    shutil.copy2(src, dst)
    print(f"Copied to {dst}")


if __name__ == "__main__":
    main()
