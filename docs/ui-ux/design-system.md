# PrepperApp Design System - Emergency UI

## Core Principles

### 1. Maximum Readability Under Stress
- Users may be injured, panicked, or in low-light conditions
- Every design decision must enhance clarity and speed
- Assume shaking hands and impaired vision

### 2. Battery Conservation First
- Pure black backgrounds for OLED power saving
- No animations or transitions
- Minimal CPU/GPU usage

### 3. One-Handed Operation
- All critical functions accessible with thumb
- Large touch targets (minimum 48x48dp)
- Bottom-heavy navigation

### 4. Instant Access
- Search bar always visible
- Maximum 2 taps to any critical info
- No loading screens or splash pages

## Color System

### Primary Palette
```css
/* OLED Optimized - True black saves 40% battery */
--black-pure: #000000;      /* Background */
--white-high: #FFFFFF;      /* Primary text */
--white-medium: #E0E0E0;    /* Secondary text */
--white-low: #999999;       /* Disabled state */

/* Alert Colors - High contrast only */
--red-emergency: #FF3333;   /* Critical alerts */
--yellow-warning: #FFCC00;  /* Warnings */
--green-safe: #00CC00;      /* Safe/Success */
```

### Usage Rules
- **Background**: Always pure black (#000000)
- **Text**: White only, varying opacity for hierarchy
- **Interactive**: White with 12% opacity overlay on tap
- **Alerts**: Used sparingly, only for critical information

### Accessibility Ratios
| Element | Foreground | Background | Contrast Ratio |
|---------|------------|------------|----------------|
| Body Text | #FFFFFF | #000000 | 21:1 ✓ |
| Secondary | #E0E0E0 | #000000 | 18.1:1 ✓ |
| Minimum | #999999 | #000000 | 5.9:1 ✓ |
| Emergency | #FF3333 | #000000 | 5.9:1 ✓ |

## Typography

### Font Stack
```css
/* System fonts for instant loading */
--font-ios: -apple-system, "SF Pro Display";
--font-android: Roboto, "Noto Sans";
--font-fallback: system-ui, sans-serif;
```

### Type Scale
```css
/* Minimum 16px for stress readability */
--text-xxxl: 32px;  /* Page titles only */
--text-xxl: 24px;   /* Section headers */
--text-xl: 20px;    /* Subsection headers */
--text-lg: 18px;    /* Emphasized body */
--text-md: 16px;    /* Body text (minimum) */
--text-sm: 14px;    /* Captions (avoid) */
```

### Line Height & Spacing
```css
/* Generous spacing for clarity */
--line-height-tight: 1.2;   /* Headers */
--line-height-normal: 1.6;  /* Body text */
--line-height-loose: 1.8;   /* Lists */

--spacing-xs: 4px;
--spacing-sm: 8px;
--spacing-md: 16px;
--spacing-lg: 24px;
--spacing-xl: 32px;
```

## Component Library

### Search Bar (Primary Component)
```swift
// iOS Implementation
struct EmergencySearchBar: View {
    @State private var query = ""
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
            
            TextField("Search survival info...", text: $query)
                .foregroundColor(.white)
                .font(.system(size: 18, weight: .medium))
                .autocapitalization(.none)
                .disableAutocorrection(true)
            
            if !query.isEmpty {
                Button(action: { query = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }
}
```

### Emergency Action Buttons
```kotlin
// Android Implementation
@Composable
fun EmergencyButton(
    text: String,
    priority: Priority,
    onClick: () -> Unit
) {
    Button(
        onClick = onClick,
        modifier = Modifier
            .fillMaxWidth()
            .height(64.dp)
            .padding(horizontal = 16.dp),
        colors = ButtonDefaults.buttonColors(
            backgroundColor = when (priority) {
                Priority.CRITICAL -> Color(0xFFFF3333)
                Priority.HIGH -> Color(0xFFFFCC00)
                Priority.NORMAL -> Color(0x1AFFFFFF)
            }
        ),
        shape = RoundedCornerShape(8.dp)
    ) {
        Text(
            text = text.uppercase(),
            color = Color.White,
            fontSize = 18.sp,
            fontWeight = FontWeight.Bold
        )
    }
}
```

### Content Cards
```css
.emergency-card {
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 8px;
    padding: 16px;
    margin-bottom: 12px;
}

.emergency-card__title {
    font-size: 20px;
    font-weight: 700;
    color: #FFFFFF;
    margin-bottom: 8px;
}

.emergency-card__content {
    font-size: 16px;
    line-height: 1.6;
    color: #E0E0E0;
}

.emergency-card--critical {
    border-color: #FF3333;
    background: rgba(255, 51, 51, 0.1);
}
```

### Navigation Pattern
```
┌─────────────────────────────────┐
│         SEARCH BAR              │ ← Always visible
├─────────────────────────────────┤
│                                 │
│                                 │
│         CONTENT AREA            │ ← Scrollable
│                                 │
│                                 │
├─────────────────────────────────┤
│   MEDICAL  │  WATER  │  MORE    │ ← Fixed bottom nav
└─────────────────────────────────┘
```

## Interaction Design

### Touch Targets
```css
/* Minimum sizes for emergency use */
.touch-target {
    min-width: 48px;
    min-height: 48px;
    /* Prefer 56px for critical actions */
}

.touch-target--emergency {
    min-width: 64px;
    min-height: 64px;
}
```

### Gesture Support
- **Single Tap**: All primary actions
- **Swipe Down**: Dismiss/back (iOS pattern)
- **Swipe Up**: Reveal more content
- **Long Press**: Bookmark/save for offline
- **Pinch**: Zoom text only (no layout reflow)

### Feedback States
```css
/* Instant visual feedback */
.touchable:active {
    opacity: 0.7;
    transform: scale(0.98);
    transition: none; /* No animation */
}

/* Loading states - Avoid if possible */
.loading {
    /* Show inline, never full screen */
    opacity: 0.6;
}
```

## Layout System

### Grid System
```css
/* 4-column grid for phones, 8 for tablets */
--columns-phone: 4;
--columns-tablet: 8;
--gutter: 16px;
--margin: 16px;
```

### Responsive Breakpoints
```css
/* Mobile-first approach */
--breakpoint-sm: 320px;  /* iPhone SE */
--breakpoint-md: 375px;  /* iPhone 12/13 */
--breakpoint-lg: 768px;  /* iPad */
--breakpoint-xl: 1024px; /* iPad Pro */
```

### Safe Areas
```swift
// iOS Safe Area handling
.padding(.top, UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0)
.padding(.bottom, UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0)
```

## Icons & Imagery

### Icon Guidelines
- **Style**: Outlined only (lighter rendering)
- **Size**: Minimum 24x24, prefer 32x32
- **Color**: White only, no tints
- **Weight**: 2px stroke for clarity

### Emergency Icons
```
🩸 Bleeding      → blood-drop.svg
💊 Medical       → pill.svg
💧 Water         → water-drop.svg
🔥 Fire          → flame.svg
🏠 Shelter       → house.svg
📡 Signal        → antenna.svg
⚡ Power         → lightning.svg
🧭 Navigate      → compass.svg
```

### Image Optimization
- **Format**: WebP or AVIF only
- **Size**: Maximum 200KB per image
- **Loading**: Lazy load all images
- **Fallback**: Text description always available

## Accessibility

### Screen Reader Support
```swift
// iOS VoiceOver
Text("Apply direct pressure to wound")
    .accessibilityLabel("Apply direct pressure to wound")
    .accessibilityHint("Tap for detailed instructions")
    .accessibilityAddTraits(.isButton)
```

### High Contrast Mode
```css
@media (prefers-contrast: high) {
    /* Already high contrast by default */
    /* Ensure no gray text in this mode */
    --white-medium: #FFFFFF;
}
```

### Motion Preferences
```css
@media (prefers-reduced-motion: reduce) {
    /* No animations anyway */
    * {
        animation: none !important;
        transition: none !important;
    }
}
```

## Platform-Specific Guidelines

### iOS Adaptations
- Use SF Symbols for all icons
- Respect iOS gesture navigation
- Support Dynamic Type scaling
- Implement haptic feedback for critical actions

### Android Adaptations
- Material Design icons (outlined variant)
- Support back gesture navigation
- Implement system font scaling
- Use Android haptic feedback API

## Performance Guidelines

### Rendering Optimization
```css
/* Force GPU acceleration */
.content {
    transform: translateZ(0);
    will-change: scroll-position;
}

/* Avoid repaints */
.static-content {
    contain: layout style paint;
}
```

### Image Loading
```javascript
// Progressive image loading
const loadImage = (src, placeholder) => {
    // Show placeholder immediately
    img.src = placeholder;
    
    // Load full image in background
    const fullImage = new Image();
    fullImage.onload = () => {
        img.src = src;
    };
    fullImage.src = src;
};
```

## Emergency Mode

### Activation
- Automatic in low battery (<20%)
- Manual toggle in settings
- Triggered by rapid taps (5 taps in 2 seconds)

### Emergency Mode Changes
1. **Disable all images** - Text only
2. **Increase font size** - +2px all text
3. **Remove secondary content** - Critical only
4. **Disable search suggestions** - Direct search only
5. **Maximum contrast** - Pure white on black only

### Emergency Mode UI
```css
.emergency-mode {
    /* Force maximum contrast */
    --white-medium: #FFFFFF;
    --white-low: #FFFFFF;
    
    /* Hide non-critical elements */
    .decorative,
    .optional,
    img:not(.critical) {
        display: none;
    }
    
    /* Increase all touch targets */
    .touch-target {
        min-height: 64px;
    }
}
```

## Testing Requirements

### Device Testing Matrix
| Device | Screen | OS Version | Priority |
|--------|--------|------------|----------|
| iPhone SE | 4.7" | iOS 15+ | High |
| iPhone 13 | 6.1" | iOS 15+ | Critical |
| Pixel 4a | 5.8" | Android 11+ | High |
| Galaxy S21 | 6.2" | Android 11+ | Critical |
| iPad Mini | 8.3" | iPadOS 15+ | Medium |

### Stress Testing Scenarios
1. **One-handed use** while running
2. **Gloved hands** in winter conditions
3. **Wet screen** from rain
4. **Bright sunlight** glare
5. **Complete darkness** scenarios
6. **Shaking hands** from cold/adrenaline

### Performance Metrics
- First paint: <100ms
- Interactive: <200ms
- Search results: <300ms
- No janky scrolling (60fps maintained)
- Battery drain: <2% per hour active use