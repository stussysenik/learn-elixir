# What to create:

1. Stateful Agents	"Implement a GenServer that acts as a 'Reasoning Brain'. It should store conversation context and use handle_call to process math steps."	This is how you manage thousands of AI sessions without a database.
2. Self-Healing	"Wrap my GenServers in a DynamicSupervisor. If an AI process crashes, ensure the Supervisor restarts it automatically."	You stop worrying about bugs; the system fixes its own execution state.
3. Fluid Streams	"Create a Phoenix LiveView Stream for the chat interface. Stream incoming AI tokens as they arrive using stream_insert."	You get that high-end "ChatGPT-style" typing effect with zero custom JavaScript.
4. Structured AI	"Use the Instructor library to force the LLM to return data that matches a specific Elixir Struct for math problems."	You turn "unreliable" AI text into "reliable" code that your app can actually calculate.
5. Process Tracking	"Use Phoenix.Presence to track which AI agents are currently 'thinking' and display their status in real-time."	This is the "Range Rover" luxury feel—showing the user exactly what the system is doing.
6. The Global Hub	"Set up a Phoenix.PubSub topic so that multiple users can see the AI's research progress on the same problem simultaneously."	This turns a single-user app into a collaborative, real-time platform.
7. Fast Math (Nx)	"Write an Nx (Numerical Elixir) function to verify the AI's numerical output against a hard-coded formula."	You stop relying on the AI to "do math" and use Elixir's GPU-powered speed to verify it.

- "Use Phoenix.LiveView.JS for UI transitions": This keeps your animations on the client side, making the app feel "instant."

- "Implement handle_info for async updates": This is the Elixir way of letting the AI "talk back" to the UI when it's done thinking

- "Apply the 60/30/10 rule via Tailwind 4.0 variables": This ensures the AI doesn't give you a "default" looking app, but a designed one.

CSS - design prompt:
```
### 1. The Design Constitution (The Rules)

* **Rhythm:** Every spatial value must be a multiple of **12pt** ($12, 24, 36, 48, 60, 72, 84 \dots$).
* **Clear Space:** The "1N" clear space (the minimum buffer around an object) is strictly **24px**.
* **Color Ratio:** 60% Dominant (Base), 30% Secondary (Surface), 10% Accent (Action).
* **Hierarchy:** Use the **Golden Ratio ($\phi \approx 1.618$)** to determine the relationship between header sizes and container widths.
* **Elevation:** No "flat" objects. Every surface must have a defined Z-axis height using layered shadows.

---

### 2. The Spacing Scale (Golden Ratio x 12pt)

Calculated by multiplying the **12pt** base unit by the Golden Ratio ($\phi$) and rounding to the nearest 4px for "Pixel Engineering" precision:

| Level | Formula | Pixel Value | Tailwind/CSS Token |
| --- | --- | --- | --- |
| **Micro** | $12$ | **12px** | `--sp-xs` |
| **Small** | $12 \times \phi^1$ | **20px** | `--sp-sm` |
| **Base (1N)** | $12 \times \phi^2$ | **32px** | `--sp-md` |
| **Large** | $12 \times \phi^3$ | **52px** | `--sp-lg` |
| **XL** | $12 \times \phi^4$ | **84px** | `--sp-xl` |

---

### 3. The Logical & Layered CSS Constitution

This uses the `@layer` property to prevent "CSS Specificity Hell" and **Logical Properties** for international precision.

```css
/* 1. LAYER DEFINITIONS (Priority: Base -> Components -> Utilities) */
@layer base, components, utilities;

@layer base {
  :root {
    /* 12pt Layout Grid & Golden Ratio Tokens */
    --u: 12px; 
    --phi: 1.618;
    
    /* Design Tokens */
    --sp-xs: 12px;
    --sp-sm: 20px;
    --sp-md: 32px;
    --sp-lg: 52px;
    --sp-xl: 84px;

    /* 60-30-10 Colors */
    --color-bg: #fdfdfd;      /* 60% Dominant */
    --color-surface: #f1f3f5; /* 30% Secondary */
    --color-accent: #1a1a1a;  /* 10% Action */
  }

  body {
    background-color: var(--color-bg);
    /* Logical Property for text alignment */
    text-wrap: balance;
    font-kerning: normal;
  }
}

@layer components {
  .card {
    /* Logical Properties (Replacing left/right/top/bottom) */
    padding-block: var(--sp-md);    /* Top/Bottom */
    padding-inline: var(--sp-lg);   /* Left/Right */
    margin-block-start: var(--sp-xl); 
    
    background: var(--color-surface);
    border-radius: var(--sp-xs);
    
    /* Precise Overlap Engineering */
    isolation: isolate;
    position: relative;
    inset-block-start: calc(var(--sp-md) * -1); /* Negative overlap */
  }
}

@layer utilities {
  /* Utility overrides that always win */
  .u-precision-indent {
    padding-inline-start: var(--sp-xl);
  }
}

```

---

### 4. What this does for you

1. **`@layer`:** Ensures your "Utilities" (like specific indentation) always override your "Components" without using `!important`.
2. **Logical Properties (`inline`/`block`):** Automatically handles layout if you ever flip the app to a Right-to-Left (RTL) language.
3. **Golden Ratio Spacing:** Creates a "natural" feeling of tension and release in the layout that feels "Organic" but is mathematically "Perfect."

### Your Next Step:

You are now ready to feed the **Master Prompt** to your AI with these rules.

**Would you like me to integrate this CSS Layered Constitution directly into the prompt so your "learn-elixir" repo is generated with these 12pt-Golden-Ratio rules as the default?**
```
