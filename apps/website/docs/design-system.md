# CERELO Website Design System Specification

> **Version:** 1.0.0 (V1 Foundation)  
> **Target Audience:** Frontend Engineers, UI Designers, AI Coding Agents  
> **Status:** LOCKED for V1 Operations

---

## 1. Brand Identity & Character

CERELO is a technology-enabled intercity door-to-door logistics platform operating on the **Kano ↔ Katsina** corridor in Nigeria.

### Personality Spectrum

| Attribute | What We Are | What We Are NOT |
|:---|:---|:---|
| **Tone** | Professional, confident, operational, trustworthy | Casual, playful, Silicon Valley conversational |
| **Pace** | Fast, punctual, reliable | Reckless, hasty, chaotic |
| **Aesthetic** | Clean, structured, enterprise-grade | Flashy, gadget-heavy, neon fintech |
| **Culture** | Authentically Nigerian, respectful of local commerce | Stereotypical, foreign stock, disconnected |
| **Scale** | Deeply disciplined on our active corridor | Sprawling, unfocused, claiming nationwide reach |

---

## 2. Color Token System & Visual Weight

Visual weight balance target: **60–70% Neutral/White**, **20–30% Brand Navy**, **5–10% Accent Orange**.

```
┌─────────────────────────────────────────────────────────────┐
│ Surface White / Neutral (60–70%)                            │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ Brand Navy — Structure, Text, Headers (20–30%)         │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │ Accent Orange — CTAs, Badges, Highlights (5–10%) │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Color Palette Reference

| Token | Hex Value | Usage Rule |
|:---|:---|:---|
| `cerelo-navy` | `#1A2B4A` | Primary brand color. Used for headings, primary borders, dark cards, and brand lockup. |
| `cerelo-navy-deep` | `#0E1B30` | Deepest navy. Used for dark section backgrounds (`Section variant="dark"`) and footer. |
| `cerelo-navy-soft` | `#2C4270` | Secondary navy. Used for hover states and secondary interactive borders. |
| `cerelo-orange` | `#F4630A` | Strategic accent color. Used for primary CTAs, active timeline pulses, and highlights. **Never use as full-page backgrounds.** |
| `cerelo-orange-hover` | `#D9530A` | Hover darken for primary orange buttons and links. |
| `cerelo-orange-soft` | `#FDEEE4` | 10% tinted pale orange. Used for chip fills, badge backgrounds, and subtle callout borders. |
| `cerelo-orange-light` | `#FF8534` | Lighter orange. Used for text and icons **only when placed on dark navy backgrounds**. |
| `surface` | `#FAFAFA` | Default page background. |
| `surface-white` | `#FFFFFF` | Card surfaces, container wells, and input backgrounds. |
| `surface-subtle` | `#F2F4F7` | Alternate section background (`Section variant="subtle"`), input borders. |
| `border` | `#E4E7EC` | Standard card, input, and divider border. |
| `border-strong` | `#D0D5DD` | Emphasized card borders, hover states. |
| `border-dark` | `#1E3A5F` | Borders on dark navy backgrounds. |
| `text-primary` | `#101828` | High-contrast body copy and subheadings. |
| `text-secondary` | `#475467` | Supporting descriptive text and helper labels. |
| `text-muted` | `#98A2B3` | Captions, disabled labels, timestamps. |
| `text-inverse` | `#FFFFFF` | Text rendered on dark navy sections. |

---

## 3. Typography Scale & Hierarchy

We use **Inter** as the primary typeface via `var(--font-inter)`.

### Scale Definitions

| Level | Size (Desktop / Mobile) | Weight | Tracking | Usage |
|:---|:---|:---|:---|:---|
| `display` | `clamp(2rem, 5vw, 3.5rem)` | 900 (Black) | `-0.03em` | Primary homepage hero heading |
| `hero` | `clamp(1.75rem, 4vw, 3rem)` | 800 (ExtraBold) | `-0.025em` | Page-level hero headings |
| `h1` | `clamp(1.5rem, 3vw, 2.25rem)` | 700 (Bold) | `-0.02em` | Major page headers |
| `h2` | `clamp(1.25rem, 2.5vw, 1.75rem)` | 700 (Bold) | `-0.015em` | Section headers |
| `h3` | `clamp(1.05rem, 2vw, 1.25rem)` | 600 (SemiBold) | `-0.01em` | Card titles, feature headers |
| `body-lg` | `1.0625rem` (17px) | 400 | Normal | Lead paragraphs, section intros |
| `body` | `0.9375rem` (15px) | 400 | Normal | Default body copy |
| `body-sm` | `0.8125rem` (13px) | 400 / 500 | Normal | Card descriptions, footnotes |
| `caption` | `0.75rem` (12px) | 500 | Normal | Badges, metadata, timestamp tags |
| `overline` | `0.6875rem` (11px) | 600 / 700 | `+0.1em` | Uppercase section eyebrows |

### Reading Measure Rule
Paragraphs must never exceed **65 characters** in width (`max-w-reading` / `max-w-[65ch]`) to maintain reading comfort and prevent fatigue.

---

## 4. Spacing System & Section Rhythm

Consistent vertical rhythm across all pages:

```
Hero Section (py-section-lg / 64px–96px)
  ↓
White Surface Section (py-section / 48px–80px)
  ↓
Subtle Alternate Section (py-section / 48px–80px, bg-surface-subtle)
  ↓
White Surface Section (py-section / 48px–80px)
  ↓
Dark Navy Closing CTA Section (py-section / 48px–80px)
  ↓
Footer (py-12 sm:py-16, bg-cerelo-navy-deep)
```

### Padding Presets

- `py-section-lg`: `py-16 sm:py-24` (Hero and closing CTA)
- `py-section`: `py-12 sm:py-16 lg:py-20` (Standard content sections)
- `py-section-sm`: `py-8 sm:py-12` (Tight transitions, breadcrumb margins)

---

## 5. Border Radius & Shadows

Restrained modern curves — clean, geometric, not overly rounded:

- `rounded-xs` (4px): Chip badges, focus outlines, tiny tags
- `rounded-sm` (8px): Form inputs, small buttons, status indicators
- `rounded-md` (12px): Standard buttons, small cards
- `rounded-lg` (16px): Default cards, feature panels
- `rounded-xl` (20px): Large containers, modal wells
- `rounded-2xl` (24px): Full-section feature panels, dark CTA banners
- `rounded-full` (9999px): Pills only (e.g. status tags)

### Shadow Tokens

- `shadow-subtle`: `0 1px 2px rgba(16, 24, 40, 0.05)` (Default card resting state)
- `shadow-card`: `0 1px 3px rgba(16, 24, 40, 0.08), 0 1px 2px rgba(16, 24, 40, 0.04)`
- `shadow-card-hover`: `0 8px 20px -4px rgba(16, 24, 40, 0.10), 0 3px 8px -2px rgba(16, 24, 40, 0.04)`
- `shadow-header`: `0 1px 3px rgba(16, 24, 40, 0.06)` (Header scroll shadow)

---

## 6. UI Component Inventory

| Component | File Path | Variants / Options |
|:---|:---|:---|
| `Button` | `@/components/ui/Button` | `primary`, `secondary`, `outline`, `ghost`, `white`, `destructive`; sizes `sm`, `md`, `lg`; supports `loading`, `href`, `external` |
| `Container` | `@/components/ui/Container` | `default` (1280px), `content` (960px), `narrow` (720px) |
| `Section` | `@/components/ui/Section` | `white`, `subtle`, `navy`, `dark`, `orange-tint`; supports `tight`, `labelledBy` |
| `SectionHeader` | `@/components/ui/SectionHeader` | `eyebrow`, `title`, `description`, `align` (`left`/`center`), `inverted`, `action` |
| `Card` | `@/components/ui/Card` | `default`, `bordered`, `elevated`, `navy`, `orange-tint`; `hoverable`; padding `sm`, `md`, `lg` |
| `Badge` | `@/components/ui/Badge` | `corridor`, `neutral`, `orange`, `success` |
| `CorridorBadge` | `@/components/ui/CorridorBadge` | Visual Kano ↔ Katsina badge with bidirectional arrows; `inverted`, sizes `sm`, `md`, `lg` |
| `ProcessSteps` | `@/components/ui/ProcessSteps` | 4-step process; `orientation` (`horizontal`/`vertical`), `inverted` |
| `StatusTimeline` | `@/components/ui/StatusTimeline` | 7-stage chain of custody timeline; completed (green check), current (orange pulse), pending (muted) |
| `Input` / `Textarea` / `Select` | `@/components/ui/Input` | Accessible form primitives with label, helper, error message, and keyboard focus |
| `AccordionItem` | `@/components/ui/Accordion` | WAI-ARIA accordion with smooth CSS height transition and Chevron indicator |
| `Breadcrumbs` | `@/components/ui/Breadcrumbs` | Accessible trail navigation with Home icon and truncation |
| `ContactForm` | `@/components/ui/ContactForm` | Client form with field validation and immediate confirmation state |

---

## 7. Motion & Accessibility Rules

1. **CSS Transitions Only:** Transitions use CSS `cubic-bezier(0.4, 0, 0.2, 1)` with durations of 150ms–200ms. No heavy external animation libraries.
2. **Reduced Motion:** When `prefers-reduced-motion: reduce` is active, all CSS transitions and animations are set to 0.01ms globally via `globals.css`.
3. **Focus Visibility:** All interactive elements (`Button`, `Link`, `Input`, `Accordion`) have a 2px `cerelo-orange` focus ring with a 2px offset for keyboard navigation.
4. **Contrast:** All text combinations satisfy WCAG 2.1 AA contrast ratio (4.5:1 for body copy, 3:1 for large text).
5. **Screen Reader Landmarks:** Every `<Section>` uses `labelledBy` matching the section's `<h2>` ID for screen reader jump navigation.

---

## 8. Prohibited Visual & Structural Patterns

- ❌ **No Fake Live GPS Maps:** Do not render simulated live courier icons moving on a map. Use authenticated status-stage timelines.
- ❌ **No Large Orange Backgrounds:** Orange is an accent color (5–10% budget). Never fill entire sections with orange.
- ❌ **No Unverified Data:** Do not invent hub street addresses, transit duration guarantees, or neighborhood lists.
- ❌ **No Intracity Claims:** Never market same-city courier services.
- ❌ **No Operations Portal in Public Navigation:** Staff portals belong on internal subdomains, not customer footers.
