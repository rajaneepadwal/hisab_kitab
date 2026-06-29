# 💸 HisabKitab – Expense Tracker App

A simple yet thoughtful expense tracking app focused on **clean UX, behavioral logic, and practical usability** — not just feature stacking.

---

## ✨ Features

* ✅ **No Negative Balance Rule**
  Transactions are blocked if balance is insufficient — prevents invalid financial states.

* 📊 **Recent Transactions (Top 10)**
  Home screen prioritizes the most relevant activity instead of limiting to “today”.

* 📜 **Full History Page**
  Dedicated view to access complete transaction history.

* 🌙 **Smart Day Reset (6 AM Logic)**
  Late-night expenses (e.g. 2 AM snacks) are counted as part of the *previous day*, reflecting real-life behavior.

* 🧾 **Big Purchase Handling**
  Large or exceptional expenses are tracked separately to avoid distorting daily spending patterns.

* 🎯 **Responsive UI**
  Layout adapts across screen sizes with minimal overflow or clutter.

* 🎨 **Consistent Theme System**
  Soft, minimal color palette aligned with a *non-guilt financial experience*.

---

## 🧠 Product Philosophy

This app is built around one core idea:

> **Financial tracking should guide behavior — not punish it.**

Key principles:

* No guilt-driven UX (no harsh warnings or negative states)
* Track realistically, not rigidly
* Focus on *what remains*, not just what was spent
* Handle edge cases like real life (late nights, irregular spending)

---

## ⚙️ System Design Decisions

This project emphasizes **behavioral correctness + system thinking** over just UI.

* 🧩 **Centralized Logic (Database Helper)**
  Business rules like day reset, savings, and validation are handled at a single source.

* 🔄 **State Persistence**
  Data is stored locally to ensure continuity across sessions.

* 🕒 **Custom Day Boundary (6 AM)**
  Avoids incorrect classification of late-night spending.

* 🚫 **Invalid State Prevention**
  Instead of fixing errors later, invalid inputs are blocked at the source.

* 🧠 **Separation of Concerns**
  UI, logic, and data handling are structured independently for clarity.

---

## 🛠 Tech Stack

* Flutter (UI)
* Dart (logic)
* SQLite (local database via sqflite)

---

## 🤖 About AI Usage

AI tools were used as **assistants, not decision-makers**:

* Helped speed up implementation
* Assisted in debugging and structuring code

However:

> **All product decisions, logic design, and UX thinking were independently planned and iterated.**

Development followed an **iterative approach**:

* Plan → Review → Refine → Implement → Re-evaluate

---

## 🧪 Testing Approach

Instead of only relying on UI testing, the app was validated through **scenario-based logic testing**:

* Normal spending flow
* Overspending conditions
* Late-night transactions (pre-6 AM)
* Big purchase edge cases
* App restart and persistence checks

---

## 🚀 Future Improvements

* Category-based expense tracking
* Visual insights and charts
* Budget planning tools
* Notifications/reminders
* Enhanced analytics on spending behavior

---

## 📌 Status

Actively under development — currently focused on **logic validation and UX refinement** before feature expansion.

---

## 💭 Key Takeaway

This project reinforced a fundamental idea:

> Good software isn’t just about writing code —
> it’s about designing systems that behave correctly in real life.

---

## 🧩 Naming

**HisabKitab** reflects the idea of everyday financial awareness in a simple, familiar way —
while the app itself aims to make that process **calm, intuitive, and non-judgmental**.
