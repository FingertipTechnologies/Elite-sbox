# Schemes — User Manual

This manual explains how to set up and use **Schemes** in the system, end to end:

- **Part A — Scheme Product Group creation** (the reusable list of products a scheme applies to)
- **Part B — Scheme creation** (the offer itself: type, tiers/slabs, validity, targeting)
- **Part C — How schemes appear and apply during Order creation**

It also includes worked examples and a "why isn't my scheme showing?" troubleshooting checklist.

---

## 1. Overview & Key Concepts

A **Scheme** is a promotional offer (free quantity, per-unit discount, free product, or % discount)
that automatically applies to **Secondary Customer** orders when the customer, sales channel,
location and products all match.

### The building blocks

| Object | What it is | Created via |
|---|---|---|
| **Scheme Product Group** | A named, reusable list of products (SKUs) for a sales channel. Group-based schemes point at one of these. | Scheme Product Group builder screen |
| **Scheme Product Group Item** | One product (SKU) inside a group. | Added inside the group builder |
| **Scheme** | The offer header — name, type, sales channel, validity dates, and what it links to. | Scheme creation wizard |
| **Scheme Slab** | A benefit **tier** under a scheme (e.g. "Buy 10 → get 2 free", "Order ₹10,000–₹19,999 → 1% off"). A scheme can have many slabs. | Inside the Scheme wizard (Slab Definition) |
| **Scheme Applicability** | The targeting rows — which Regions / Areas / Territories / Outlet Categories the scheme is valid for. | Inside the Scheme wizard (Applicability step). Created automatically on Save. |

### The five Scheme Types

| Scheme Type | What the customer gets | Links to | Slab is based on |
|---|---|---|---|
| **Free Quantity** | Free units of the **same** product group (price diluted across the free units). | A Product Group | Quantity |
| **QPS** (Quantity Purchase Scheme) | A flat **₹ per unit** discount. | A Product Group | Quantity |
| **FOC Giveaway** | Free units of a **different** (free-of-cost) product. | A Product Group | Quantity |
| **Category Value** | A **% discount** on the value of a product sub-group/category. | A Product Category (sub-group) | Order/category value (₹) |
| **Order Value** | A **% discount** on the **whole order** value. | Nothing (applies to the entire order) | Order value (₹) |

> **Rule of thumb:** Free Quantity, QPS and FOC Giveaway need a **Scheme Product Group**.
> Category Value needs a **Product Category**. Order Value needs **no** product linkage.

---

## Part A — Creating a Scheme Product Group

A Scheme Product Group is the reusable bucket of SKUs that a group-based scheme (Free Quantity,
QPS, FOC Giveaway) points at. Create the group **first**, then reference it when you build the scheme.

### A.1 Open the builder
Open the **Scheme Product Group** screen and click **New** (or open an existing group to edit it).

### A.2 Fill the header
At the top, set:

| Field | Required | Notes |
|---|---|---|
| **Name** | Yes | A clear, recognizable name, e.g. *"Pudding Cake 500 G"*. |
| **Group Purpose** | Yes | **Price Division** — for Free Quantity / QPS groups. **FOC Qualifier** — for FOC Giveaway "buy" groups. (This is how the scheme wizard later filters which groups you can pick.) |
| **Sales Channel** | Yes | The channel this group belongs to. The SKU list below loads **only after** a channel is chosen. |
| **Description** | No | Optional notes. |
| **Active** | — | Toggle **Yes** to make the group usable; **No** keeps it as a draft. |

> Until you select a **Sales Channel**, the product table stays hidden with the hint
> *"Select a Sales Channel."*

### A.3 Find the products
Once a channel is selected, the SKU table loads. Narrow it down with the filter row:

- **Category**, **Product Group**, **Sub Group**, **Variant**, **Grammage (g)**, **MRP**
- **Search SKU** — type a product name or SKU code.

Helper buttons:
- **Clear Filters** — reset all filters.
- **Select All Visible** — tick every row currently shown by the filters.
- **Clear Selection** — untick everything.
- **All / Selected (n)** toggle — switch between the full list and just your picked items.

### A.4 Select the SKUs
Tick the checkbox on each product you want in the group. The header shows a live **"n selected"** count.

The table columns are: **SKU Code, Product Name, Category, Group, Sub Group, Variant, Grammage, MRP**,
and a **warning (⚠) flag**.

> **Conflict warning (⚠):** If a SKU already belongs to **another** group with the **same purpose
> and channel**, a warning icon appears (hover to see which group). Avoid putting the same SKU in
> two competing groups, or schemes can overlap unexpectedly.

### A.5 Save
Click **Save**. The group and its selected products (Scheme Product Group Items) are stored together.
The group is now available to pick in the Scheme wizard.

> **Tip:** Keep groups focused (e.g. one pack size / brand family). You'll reuse them across many
> schemes over time.

---

## Part B — Creating a Scheme

Schemes are built in a **2-step wizard**: **① Definition** and **② Applicability**. Open the
**Scheme** tab and click **New** (existing schemes open the same wizard in edit mode).

The stepper at the top shows **1 Definition → 2 Applicability**. Use **Next / Back**, and **Save**
on the last step. **Cancel** discards.

### Step 1 — Definition

Step 1 has three cards: **Master Details**, **Product Group / Category**, and **Slab Definition**.

#### B.1 Master Details

| Field | Required | Notes |
|---|---|---|
| **Scheme Name** | Yes | Shown to order-takers, so make it descriptive (e.g. *"QPS Scheme – Pudding Cakes"*). |
| **Sales Channel** | Yes | Drives which product groups/FOC products you can pick, and which customers see the scheme. |
| **Scheme Type** | Yes | One of Free Quantity / QPS / FOC Giveaway / Category Value / Order Value. **This choice changes the linkage card and the slab columns below.** |
| **Scheme Start Date** | Yes | First day the scheme is live. Cannot be set in the past for a new scheme. |
| **Scheme End Date** | Yes | Last day the scheme is live (must be on/after the start date). |
| **Active** | — | Toggle on to make it live (in addition to being within the date range). |
| **Description** | No | Optional internal notes. |

#### B.2 Product Group / Category (linkage)

What this card shows depends on the **Scheme Type** you picked:

- **Free Quantity / QPS / FOC Giveaway →** a **Scheme Product Group** search.
  It lists *active* groups for your **Sales Channel** with the matching **Group Purpose**
  (Price Division for Free Qty/QPS, FOC Qualifier for FOC). Search by name and click to select; use
  **Change** to pick a different one.
- **Category Value →** a **Scheme Product Category** dropdown. Pick the sub-group/category whose
  value drives the discount.
- **Order Value →** no linkage needed — you'll see *"No product linkage required. Order Value
  schemes apply to the order's overall value."*

> If you haven't chosen a Scheme Type **and** Sales Channel yet, this card shows
> *"Pick Scheme Type and Sales Channel first."*

#### B.3 Slab Definition (the tiers)

Add one or more **slabs** (tiers). The columns adapt to the Scheme Type. Use **Add Slab** to add a
row and the trash icon to remove one.

| Scheme Type | Slab columns | Meaning |
|---|---|---|
| **Free Quantity** | Min Qty, Max Qty, **Free Qty** | Buy within the qty band → get *Free Qty* free units. |
| **QPS** | Min Qty, Max Qty, **Benefit ₹/EA** | Buy within the qty band → *₹X* off **each** unit. |
| **FOC Giveaway** | Min Qty, Max Qty, **FOC Product** (search), **Free Qty** | Buy within the qty band → get *Free Qty* units of the chosen FOC product, free. |
| **Order Value** | Min Value (₹), Max Value (₹), **Discount %** | Order value in the band → *X%* off the order. |
| **Category Value** | Min Value (₹), Max Value (₹), **Discount %** | Category value in the band → *X%* off that category. |

**How tiers are chosen at order time:** the system picks the **highest tier the order qualifies
for** (by total quantity for qty-based schemes, or total value for value-based schemes).

**Multi-tier example (Free Quantity):**

| Min Qty | Max Qty | Free Qty |
|---|---|---|
| 10 | 19 | 1 |
| 20 | (blank = no upper limit) | 3 |

Ordering 25 EA → falls in the second tier → the engine grants free units based on that tier.

**FOC Product search:** in an FOC slab, click the FOC Product cell, search by name or SKU code (the
list is scoped to the scheme's Sales Channel), and pick the giveaway product. Use the ✕ to change it.

#### B.4 Next
When Step 1 is valid, click **Next** to go to Applicability.

### Step 2 — Applicability (targeting)

This is where you decide **which customers** the scheme reaches. There are four levels, each with an
**"Apply to all"** toggle:

- **Outlet Categories**
- **Regions**
- **Areas**
- **Territories**

For each level:
- Leave **Apply to all** **ON** → the scheme matches every value at that level.
- Turn it **OFF** → a dual-list box appears; move the specific **Available** values into
  **Selected** to restrict the scheme to just those.

> Example: *Apply to all Regions = ON*, but *Areas = OFF* with only "North Zone" selected →
> the scheme runs in every region but only for the North Zone area.

### B.5 Save
Click **Save**. The system saves the **Scheme**, all its **Slabs**, and the **Applicability** rows
together in one action. You can re-open the scheme anytime to edit it (the wizard re-hydrates with
your saved values).

> **Activation checklist** — a scheme only goes live when **all** are true: **Active = on**,
> today is within **Start/End** dates, the **Sales Channel** matches, the **Applicability** matches
> the customer, and the **linked group/category** has products.

---

## Part C — How Schemes Appear During Order Creation

When a salesperson creates a **Secondary Customer** order, matching schemes show up automatically and
prices recalculate as quantities are entered.

### C.1 Which schemes appear (coverage rules)

A scheme appears for a customer when **all** of the following hold:

1. The account is a **Secondary Customer** (primary customers don't see these schemes).
2. The scheme's **Sales Channel** matches the customer's channel.
3. **Today is within** the scheme's Start–End dates **and** the scheme is **Active**.
4. The customer's **Region / Area / Territory** match the scheme's applicability (or the scheme is
   "Apply to all" for that level).
5. The customer's **Outlet Category** matches (or "Apply to all Outlet Categories").
6. The scheme has **product membership** — a product group, a category, or it's an Order Value
   scheme (whole order).

### C.2 The "Running Schemes" list

The order screen shows a **Running Schemes** panel of cards — one per applicable scheme. Each card
shows:

- **Scheme name** and **Scheme Type**.
- **Offer tiers** as plain sentences, for example:
  - Free Quantity → **🛒 Buy 10 EA → 🎁 Get 2 EA Free**
  - QPS → **🛒 Buy 42 to 71 EA → 💰 ₹1 off per EA**
  - FOC Giveaway → **🛒 Buy 20 EA → 🎁 Get 3 EA of *(product)* Free**
  - Category / Order Value → **🛒 Order ₹10000 to ₹19000 → 💰 1% Off** (or "₹10000 or more")
  - Multiple tiers are labelled **Tier 1, Tier 2, …**; a single tier is labelled **Offer**.
- **Validity** — e.g. **31-05-2026 to 30-06-2026**.
- **Group + member products** (name + SKU) for group schemes, or the **Category** for category schemes.

(In the invoice wizard, each card can be expanded/collapsed with the chevron.)

### C.3 Indicators on each product row

- A **ribbon / ⭐ icon** marks products that belong to a running scheme.
- When a scheme actually applies to a line, a **price band** shows the **discounted unit price**
  next to the **original price**, plus a **tag with the scheme name**. A breakup control reveals the
  step-by-step price changes (Base → Free Quantity → QPS → …).

### C.4 What each scheme type does to the price (plain language)

As quantities are entered, the engine recalculates in a fixed order. Multiple schemes can apply to
the same products.

- **Free Quantity** — totals the group's quantity, works out the free units for the qualifying tier,
  and **dilutes the unit price** so the free units are reflected (e.g. effective price drops because
  you're getting extra units at no charge).
- **QPS** — **subtracts the ₹/EA** benefit from each unit's price for the qualifying tier.
- **FOC Giveaway** — adds the free product. If that product is already on the order, the free units
  are **merged** into that line (shown as **"+n free"**); otherwise a new **FREE** line is added at
  zero net cost.
- **Category Value** — calculates the **% discount on the category's value** and shows it as a
  **header discount** (not per line).
- **Order Value** — calculates the **% discount on the whole order** and shows it as a **header
  discount**.

For value-based schemes, the system always uses the **highest tier the order value qualifies for**.

### C.5 The order summary

The summary reflects all scheme effects:

- **FOC / free lines** are tagged **FREE** (or a line shows **"+n free"** for merged units).
- Per-line prices show the **discounted unit price**.
- **Header discounts** appear when present:
  - **Category Value Discount** – ₹…
  - **Order Value Discount** – ₹…
  - **Net Payable** = Grand Total (subtotal + tax) − header discounts.

Every applied benefit is also recorded against the order for auditing/claims (which scheme, which
tier, the benefit amount, free quantity, etc.).

---

## Part D — Troubleshooting: "Why isn't my scheme showing?"

Work down this checklist:

1. **Active & dates** — Is the scheme **Active**, and is **today between** its Start and End dates?
2. **Customer type** — Is the order for a **Secondary Customer**? Primary customers don't see these.
3. **Sales channel** — Does the scheme's **Sales Channel** match the customer's channel?
4. **Applicability** — Do the customer's **Region / Area / Territory / Outlet Category** match the
   scheme's targeting? If you restricted any level, confirm the customer's value is in the
   **Selected** list (or switch that level to **Apply to all**).
5. **Product linkage** —
   - Group schemes: does the **Scheme Product Group** contain the products being ordered, and is the
     group **Active** with the **right Group Purpose** and **Sales Channel**?
   - Category Value: is the **Scheme Product Category** correct, and are products from it on the order?
6. **Quantity / value threshold** — Has the order reached a slab's **Min Qty** or **Min Value**?
   Below the lowest tier, nothing applies. (In the invoice wizard, reducing quantity below the
   threshold removes the benefit and flags it as a scheme issue.)
7. **Group conflicts** — Was the SKU accidentally placed in **two** groups of the same purpose/channel
   (the ⚠ flag in the group builder)? Clean up duplicates.

---

### Quick reference — which fields matter per Scheme Type

| Scheme Type | Linkage | Slab inputs | Result |
|---|---|---|---|
| Free Quantity | Product Group | Min/Max Qty, Free Qty | Free units of same group |
| QPS | Product Group | Min/Max Qty, Benefit ₹/EA | ₹ off per unit |
| FOC Giveaway | Product Group | Min/Max Qty, FOC Product, Free Qty | Free units of another product |
| Category Value | Product Category | Min/Max Value, Discount % | % off the category value |
| Order Value | (none) | Min/Max Value, Discount % | % off the whole order |
