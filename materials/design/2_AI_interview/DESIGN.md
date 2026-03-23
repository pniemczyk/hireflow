# Design System Document: The Ethereal Agent

## 1. Overview & Creative North Star
**Creative North Star: The Living Void**
This design system moves away from the "dashboard-as-a-tool" cliché and toward "interface-as-an-entity." The goal is to create an atmosphere of quiet intelligence. By leveraging deep charcoal foundations and glassmorphic overlays, the interface feels less like a static webpage and more like a high-end physical device—a slab of polished obsidian imbued with a digital soul.

We break the "template" look by eschewing rigid boxes. Instead, we use intentional asymmetry and "breathing" whitespace to center the conversation. Elements do not just appear; they materialize through tonal shifts and soft glows, ensuring the AI agent feels premium, authoritative, and sophisticated.

---

## 2. Colors & Surface Philosophy
The palette is rooted in the depth of `surface` (#131313), using light not as a divider, but as a medium.

### The "No-Line" Rule
**Explicit Instruction:** 1px solid borders are strictly prohibited for sectioning. Traditional "dividers" are a relic of low-resolution design. In this system, boundaries are defined exclusively by:
- **Background Color Shifts:** A `surface-container-low` (#1C1B1B) card sitting on a `surface` (#131313) base.
- **Tonal Transitions:** Using the spacing scale to let negative space act as the separator.

### Surface Hierarchy & Nesting
Treat the UI as a series of nested physical layers. 
- **Base Layer:** `surface` (#131313)
- **Secondary Content Area:** `surface-container-low` (#1C1B1B)
- **Interactive Floating Elements:** `surface-container-high` (#2A2A2A) with 80% opacity and 12px backdrop-blur.
- **High-Emphasis Modals:** `surface-container-highest` (#353534).

### The "Glass & Gradient" Rule
To achieve the "Aura" effect requested for processing states:
- **Processing State:** Use a radial gradient transition from `primary` (#9ECAFF) at 15% opacity to transparent, localized behind the waveform or agent avatar.
- **Success States:** Use `secondary` (#78DC77) with a subtle glow (outer glow, blur 20px, 10% opacity) rather than a flat green block.

---

## 3. Typography: Editorial Authority
We utilize a dual-font strategy to balance character with utility.

- **The Display/Headline Layer (Manrope):** Chosen for its geometric precision. Use `display-lg` and `headline-md` for agent greetings and high-score celebrations. The wide tracking and bold weights convey a "New Tech" editorial feel.
- **The Intelligence Layer (Inter):** Used for the core conversation (`body-lg`) and technical metadata (`label-sm`). Inter provides the neutral, high-readability "voice" of the AI.

**Hierarchy Note:** Always maintain a high contrast between `headline-lg` (2rem) and `body-md` (0.875rem). This "High-Low" scale mimics premium print journalism and removes the "generic SaaS" aesthetic.

---

## 4. Elevation & Depth
In a dark, minimalist interface, depth is the primary way we communicate importance.

### The Layering Principle
Never use a shadow where a tonal shift can work. 
- Place a `surface-container-lowest` (#0E0E0E) input field inside a `surface-container-low` (#1C1B1B) chat panel to create a "recessed" look.

### Ambient Shadows
For floating elements (Tooltips, Popovers):
- **Blur:** 24px - 40px.
- **Opacity:** 6% of `on-surface` (#E5E2E1).
- **Tint:** Shadows must be tinted with a hint of `primary` (#9ECAFF) to keep the dark mode from looking "muddy" or "gray."

### The "Ghost Border" Fallback
If contrast testing requires a boundary for accessibility, use the `outline-variant` (#404752) at **15% opacity**. It should be felt, not seen.

---

## 5. Components

### The Conversation Hub (Main Interface)
- **Centering:** The conversation thread must be max-width 800px, centered with generous `24` (8.5rem) side margins on desktop to focus the user’s gaze.
- **Waveform Indicator:** Uses `primary` (#9ECAFF). The waveform should not be a flat line; use a 2px stroke with a `primary-container` (#2196F3) outer glow.

### Buttons
- **Primary:** `primary` (#9ECAFF) background with `on-primary` (#003258) text. Shape: `full` (9999px) for a modern, friendly feel.
- **Tertiary (Ghost):** No background. Use `label-md` uppercase with 0.1em letter spacing. Interaction state: subtle `surface-bright` (#3A3939) background on hover.

### Input Fields
- **Style:** No bottom line, no border. Use `surface-container-lowest` (#0E0E0E) with a `lg` (1rem) corner radius. 
- **Active State:** A soft `primary` (#9ECAFF) inner glow (2px blur) rather than a heavy border.

### Chips (Metadata & Scores)
- **High Score Chip:** `secondary-container` (#00761F) background with `on-secondary-container` (#95FB92) text. Use `sm` (0.25rem) radius to differentiate from rounded buttons.

### Cards (The "No-Divider" List)
- Forbid 1px dividers between list items. Use `spacing-4` (1.4rem) to separate items. If separation is visually weak, use alternating `surface` and `surface-container-low` backgrounds.

---

## 6. Do’s and Don'ts

### Do:
- **Do** use `20` (7rem) and `24` (8.5rem) spacing scales to create "luxury whitespace."
- **Do** use Glassmorphism (`backdrop-blur`) for any element that overlaps the conversation (e.g., fixed headers or tooltips).
- **Do** use the `secondary` (#78DC77) green for "High Scores" to create a rewarding "vibrant" moment against the dark base.

### Don't:
- **Don't** use pure #000000. It kills the depth of the glassmorphic effects. Stick to the `surface` (#131313) token.
- **Don't** use standard "drop shadows" with 0 blur. 
- **Don't** use icons without tooltips. The system is minimalist; tooltips (using `surface-container-highest`) provide the necessary affordance.
- **Don't** use 100% opaque red for errors. Use `error` (#FFB4AB) at a slightly reduced weight to keep the "Soft Red" aesthetic.