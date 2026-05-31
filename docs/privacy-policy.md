---
layout: default
title: Privacy Policy
description: How Dot Clash collects, uses, and protects your information.
permalink: /privacy-policy/
show_updated: true
---

# Privacy Policy

{% assign legal = site.data.legal %}
{% assign privacy_url = site.data.legal.privacy_policy_path | absolute_url %}

{{ legal.entity_name }} ("we," "us," or "our") operates **Dot Clash**, a mobile game for iOS and Android (the "**App**"). This Privacy Policy explains how we collect, use, disclose, and protect information when you use the App.

By using the App, you agree to this Privacy Policy. If you do not agree, do not use the App.

## Who we are

- **App name:** Dot Clash
- **Developer:** {{ legal.entity_name }}
- **Email:** [{{ legal.contact_email }}](mailto:{{ legal.contact_email }})
- **Address:** {{ legal.postal_address }}
- **Website:** {{ legal.website_url }}

## Scope

This policy applies to the App and related services (cloud save, in-app purchases, advertising). It does not apply to third-party websites or services you open through links in the App.

## Information you provide

- If you sign in with **Google** or **Apple**, we receive identifiers and profile information those providers allow (for example display name and email if shared).
- You may play as a **guest** using anonymous **Firebase Authentication**; we assign a user ID without requiring an email.
- You may set a **display name** stored with your game profile.
- If you contact us by email, we receive your message and email address.

## Game and profile data (when signed in)

We store gameplay and progression data linked to your account, including:

- Campaign progress, stars, and levels completed
- Daily puzzle status and streaks
- Wins, losses, ratings, seasons, lives, coins, XP, and daily missions
- Cosmetic choices and owned items
- Remove Ads purchase status
- Timestamps for rewards, daily claims, and optional ad-based rewards

This data is stored in **Google Firebase Cloud Firestore** under your user ID.

## Information collected automatically

- Device and app information (device type, OS, app version, language, diagnostics)
- **Firebase Analytics** (how the App is used; may be linked to your user ID when signed in)
- **Firebase Crashlytics** in release builds (crash logs; may be linked to your user ID)
- **Firebase App Check** (helps protect our backend from abuse)
- Local settings on your device (for example sound and haptics preferences)

## Advertising

We use **Google AdMob**, including:

- **Rewarded video ads** (optional; for example extra lives, shop coins, match retry)
- **Interstitial ads** (after certain matches, unless you bought Remove Ads)

AdMob and partners may collect or receive:

- Advertising ID on Android and, if you allow it, IDFA on iOS
- IP address (often truncated), device identifiers, ad interactions, coarse location from IP
- Consent choices through **Google User Messaging Platform (UMP)** in the EEA, UK, and Switzerland

{% if legal.personalized_ads %}

We may show **personalized ads** tailored to your interests using advertising identifiers and similar technologies, subject to your consent where required (including **UMP** in the EEA/UK/CH and **App Tracking Transparency** on iOS). You can limit tracking in device settings and through in-app consent prompts.

{% else %}

We use **non-personalized ads** only. Ads are not tailored to you based on cross-app tracking. You may still see contextual ads (for example based on app content or general location from IP).

{% endif %}

If you purchase **Remove Ads** (product ID: `dot_clash_remove_ads`), interstitial ads stop. Rewarded ads may still appear only if you choose to watch them for in-game benefits.

## Payments

Purchases are processed by **Apple App Store** or **Google Play**. We do not receive your full card number. We receive purchase confirmation and entitlement status (for example `removeAds` on your profile).

## How we use information

We use information to:

- Provide and operate the App (gameplay, saves, campaigns, daily content)
- Authenticate you and sync progress when you sign in
- Process in-app purchases and restore purchases
- Show ads and measure ad performance (AdMob)
- Analyze usage and improve the App (Firebase Analytics)
- Detect, prevent, and address fraud, abuse, and technical issues (App Check, security rules)
- Fix crashes and improve stability (Crashlytics)
- Comply with law and enforce our Terms
- Respond to your requests

## Legal bases (EEA/UK)

Where GDPR applies, we rely on:

- **Contract** — to provide the App and features you request
- **Legitimate interests** — security, analytics, improving the App{% unless legal.personalized_ads %}, non-personalized advertising{% endunless %}
- **Consent** — where required for ads (UMP) and, if applicable, personalized ads or iOS tracking
- **Legal obligation** — when we must comply with law

You may withdraw consent for ads where applicable; withdrawal does not affect processing already performed.

## Who we share with

We do not sell your personal information for money. We use processors including:

| Provider | Purpose |
|----------|---------|
| **Google Firebase** (Auth, Firestore, Analytics, Crashlytics, App Check, Cloud Functions) | Account, cloud save, analytics, crashes, server logic |
| **Google AdMob** | Advertising |
| **Google / Apple** | Sign-in and in-app purchase processing |

They may process data in the **United States** and other countries. We use contractual and technical safeguards where required by law.

We may also disclose information if required by law, to protect rights and safety, or in connection with a merger or sale of assets.

## Retention

- **Account data:** while your account is active and for a reasonable period afterward
- **Analytics and crashes:** per Firebase/Google retention settings
- **Ad-related data:** governed by Google’s policies and your consent settings
- **Local data:** until you uninstall the App or clear app data

## Your choices and rights

Depending on your location, you may have rights to **access**, **correct**, **delete**, **restrict**, **object**, **portability**, and to **withdraw consent**.

**Advertising choices**

- **EEA/UK/CH:** Use the in-app consent flow (UMP) when shown
- **iOS:** Settings → Privacy & Security → Tracking
- **Android:** Settings → Google → Ads
- **Remove Ads:** Purchase in the shop to disable interstitial ads

**Account and data deletion**

**In the app (recommended):** Open Dot Clash → **Settings** → **Legal & privacy** → **Delete my account**. This immediately deletes your Firebase account and Firestore profile (progress, match history, and related data). Local app data on the device is cleared when you sign out.

**If you cannot use the app:** Email [{{ legal.contact_email }}](mailto:{{ legal.contact_email }}) with subject **"Dot Clash Account Deletion"** and include your display name and sign-in method (Google, Apple, or guest). We will process the request within **{{ legal.deletion_sla }}**, except where we must retain data for legal obligations.

See [Delete your data]({{ site.data.legal.delete_data_path | absolute_url }}) for details.

**California (CCPA/CPRA)**

California residents may have rights to know, delete, and correct personal information, and to opt out of “sale” or “sharing” for cross-context behavioral advertising. We do not sell personal information for money. Contact us to exercise your rights.

**Other regions**

Contact [{{ legal.contact_email }}](mailto:{{ legal.contact_email }}) to exercise applicable rights.

## Children

Dot Clash is **not directed to children under 13** (or under 16 in some jurisdictions). We do not knowingly collect personal information from children. If you believe a child provided personal information, contact us and we will delete it.

## Security

We use authentication, Firestore security rules, and App Check. No method of transmission or storage is 100% secure.

## International transfers

We and our processors may transfer data outside your country, including the United States, with appropriate safeguards where required (for example Standard Contractual Clauses).

## Changes

We may update this Privacy Policy. We will post the new date at the top of this page and, where required, notify you in the App or through store listings. Continued use after changes means you accept the updated policy.

## Contact

**{{ legal.entity_name }}**  
[{{ legal.contact_email }}](mailto:{{ legal.contact_email }})  
{{ legal.postal_address }}
