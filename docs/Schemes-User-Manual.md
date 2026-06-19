# Schemes — User Manual

This manual explains how to set up and use **Schemes** in the system, end to end, as three
process-step parts:

- **Part 1 — Scheme Product Creation** (the reusable list of products a scheme applies to)
- **Part 2 — Scheme Creation and Applicability** (the offer itself: type, tiers/slabs, validity,
  targeting) — including the **scheme types with a worked example for each**
- **Part 3 — Creation of Order** (how schemes appear and apply when an order is placed)

A short concepts overview and a "why isn't my scheme showing?" troubleshooting checklist are included.

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

## Part 1 — Scheme Product Creation

A Scheme Product Group is the reusable bucket of SKUs that a group-based scheme (Free Quantity,
QPS, FOC Giveaway) points at. Always create the group **first**, then reference it when you build
the scheme in Part 2.

### Process steps

1. Open the **Scheme Product Group** screen and click **New** (or open an existing group to edit it).
2. Fill the **header** — Name, Group Purpose, Sales Channel, optional Description, and the **Active**
   toggle (see the field table below).
3. Select the **Sales Channel**. The SKU table stays hidden (*"Select a Sales Channel"*) until a
   channel is chosen, then loads the products for that channel.
4. Narrow the list with the **filter row** (Category, Product Group, Sub Group, Variant, Grammage,
   MRP) or the **Search SKU** box (product name / SKU code).
5. **Tick** the checkbox on each SKU you want in the group — the header shows a live *"n selected"*
   count. Watch the conflict (⚠) flag.
6. Click **Save**. The group and its selected products (Scheme Product Group Items) are stored
   together and the group becomes available in the Scheme wizard.

### Header fields

| Field | Required | Notes |
|---|---|---|
| **Name** | Yes | A clear, recognizable name, e.g. *"Pudding Cake 500 G"*. |
| **Group Purpose** | Yes | **Price Division** — for Free Quantity / QPS groups. **FOC Qualifier** — for FOC Giveaway "buy" groups. (This is how the scheme wizard later filters which groups you can pick.) |
| **Sales Channel** | Yes | The channel this group belongs to. The SKU list below loads **only after** a channel is chosen. |
| **Description** | No | Optional notes. |
| **Active** | — | Toggle **Yes** to make the group usable; **No** keeps it as a draft. |

> Until you select a **Sales Channel**, the product table stays hidden with the hint
> *"Select a Sales Channel."*

### Filter & selection helpers

Helper buttons:
- **Clear Filters** — reset all filters.
- **Select All Visible** — tick every row currently shown by the filters.
- **Clear Selection** — untick everything.
- **All / Selected (n)** toggle — switch between the full list and just your picked items.

SKU columns: **SKU Code, Product Name, Category, Group, Sub Group, Variant, Grammage, MRP**, and a
**warning (⚠) flag**.

> **Conflict warning (⚠):** If a SKU already belongs to **another** group with the **same purpose
> and channel**, a warning icon appears (hover to see which group). Avoid putting the same SKU in
> two competing groups, or schemes can overlap unexpectedly.

> **Tip:** Keep groups focused (e.g. one pack size / brand family). You'll reuse them across many
> schemes over time.

---

## Part 2 — Scheme Creation and Applicability

Schemes are built in a **2-step wizard**: **① Definition** and **② Applicability**. Open the
**Scheme** tab and click **New** (existing schemes open the same wizard in edit mode).

The stepper at the top shows **1 Definition → 2 Applicability**. Use **Next / Back**, and **Save**
on the last step. **Cancel** discards.

### Process steps

1. Open the **Scheme** tab → **New** to launch the wizard.
2. **Step 1 — Master Details:** enter the Scheme Name, Sales Channel, Scheme Type, Start/End dates,
   and the **Active** toggle.
3. **Step 1 — Linkage:** depending on the Scheme Type, pick a **Scheme Product Group** (Free Quantity
   / QPS / FOC Giveaway), a **Product Category** (Category Value), or **nothing** (Order Value).
4. **Step 1 — Slab Definition:** click **Add Slab** and fill the tier columns (they adapt to the
   Scheme Type). Add more slabs for multiple tiers; the trash icon removes a row. Click **Next**.
5. **Step 2 — Applicability:** for each level (Outlet Categories, Regions, Areas, Territories) either
   leave **Apply to all** ON or turn it OFF and move specific values into **Selected**.
6. Click **Save**. The Scheme, all its Slabs, and the Applicability rows are saved together in one
   action. Re-open the scheme anytime to edit it.

### Step 1 — Definition

Step 1 has three cards: **Master Details**, **Product Group / Category**, and **Slab Definition**.

#### Master Details

| Field | Required | Notes |
|---|---|---|
| **Scheme Name** | Yes | Shown to order-takers, so make it descriptive (e.g. *"QPS Scheme – Pudding Cakes"*). |
| **Sales Channel** | Yes | Drives which product groups/FOC products you can pick, and which customers see the scheme. |
| **Scheme Type** | Yes | One of Free Quantity / QPS / FOC Giveaway / Category Value / Order Value. **This choice changes the linkage card and the slab columns below.** |
| **Scheme Start Date** | Yes | First day the scheme is live. Cannot be set in the past for a new scheme. |
| **Scheme End Date** | Yes | Last day the scheme is live (must be on/after the start date). |
| **Active** | — | Toggle on to make it live (in addition to being within the date range). |
| **Description** | No | Optional internal notes. |

#### Product Group / Category (linkage)

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

#### Slab Definition (the tiers)

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

### Save
Click **Save**. The system saves the **Scheme**, all its **Slabs**, and the **Applicability** rows
together in one action. You can re-open the scheme anytime to edit it (the wizard re-hydrates with
your saved values).

> **Activation checklist** — a scheme only goes live when **all** are true: **Active = on**,
> today is within **Start/End** dates, the **Sales Channel** matches, the **Applicability** matches
> the customer, and the **linked group/category** has products.

### Scheme Types — with an example each

There are five scheme types. Each example shows the slab you would enter and what the customer gets
at order time.

**1) Free Quantity** — free units of the **same** product group; the free units' value is spread
(price diluted) across the line.
> *Example:* Group "Pudding Cake 500 G", slab **Min Qty 10, Max Qty 19, Free Qty 2**. The customer
> orders **12 EA** → qualifies for the 10–19 tier → gets **2 EA free**. The unit price is diluted
> across the 12 units so the 2 free units cost nothing overall.

**2) QPS (Quantity Purchase Scheme)** — a flat **₹ per-unit** discount for buying within a band.
> *Example:* Group "Pudding Cake 500 G", slab **Min Qty 42, Max Qty 71, Benefit ₹1 / EA**. The
> customer orders **50 EA at ₹20** → each unit is discounted ₹1 → pays **₹19 / EA** (₹50 saving).

**3) FOC Giveaway** — free units of a **different** (free-of-cost) product.
> *Example:* Buy group "Whole Wheat Chakki Atta", slab **Min Qty 20, FOC Product "Roasted Vermicelli
> 200 g", Free Qty 2**. Buying **20 EA of Atta** → **2 EA of Roasted Vermicelli free**. If Vermicelli
> is also ordered, the 2 free units merge into that line (**"+2 free"**); otherwise a separate **FREE**
> line is added at ₹0.

**4) Category Value** — a **% discount** on a product sub-group / category value, as a header discount.
> *Example:* Category "Plum", slab **Min Value ₹10,000, Max Value ₹19,000, Discount 1%**. The
> customer's Plum-category lines total **₹12,000** → qualifies → **1% (₹120)** comes off as a
> "Category Value Discount".

**5) Order Value** — a **% discount** on the **whole order** value (no product linkage), shown as a
header discount and reflected in Net Payable.
> *Example:* slab **Min Value ₹10,000, Max Value ₹19,000, Discount 1%**. The order totals **₹15,000**
> → **1% off**. Order Value is applied **after** any Category Value discount (on the value remaining
> after the category discount).

---

## Part 3 — Creation of Order

When a salesperson creates a **Secondary Customer** order, matching schemes show up automatically and
prices recalculate as quantities are entered. Schemes apply **only for Secondary Customers** — Primary
Customers see base prices and a *"No schemes are applicable"* message.

### Process steps

1. From the **Beat Planner** visit / Execute screen (or the Order object's **New** action), open the
   order screen for a **Secondary Customer**. The customer (account) is carried into the screen; if
   none is passed, use the **Search Customer** picker.
2. **Products screen ("All items"):** search / filter products and enter the **EA quantity** for each.
   A ⭐ / ribbon marks scheme products; an applied line shows a **discounted price band** next to the
   original price, with a breakup you can expand.
3. **Schemes ("Running Schemes") tab:** review the applicable schemes (read-only) — each card shows the
   name, type, offer tiers as sentences, validity, and the covered group/category. Expand / collapse
   with the chevron.
4. **Selected tab:** quick-review every product that has a non-zero quantity before finishing.
5. **Summary screen:** enter **Delivery To** and **Expected Delivery Date** (PO Number / PO Date appear
   for Primary Customers only). Review per-line discounted prices, **Sub Total, Tax, Grand Total**, any
   **header discounts** (Category Value / Order Value) and the resulting **Net Payable**. FOC / free
   lines are tagged **FREE** (or **"+n free"** when merged).
6. Click **Save Orders**. The system validates the required header fields and the **minimum order
   value**, captures the device **location** (GPS), then saves the order.
7. **After save:** a *"Orders saved successfully"* toast appears and you return to the visit / Execute
   screen (or the Order list view if you came from the Order New action).

> Every applied benefit is also recorded against the order for auditing / claims (Order Scheme Applied
> rows: which scheme, which tier, the benefit amount, free quantity, etc.).

### Which schemes appear (coverage rules)

A scheme appears for a customer when **all** of the following hold:

1. The account is a **Secondary Customer** (primary customers don't see these schemes).
2. The scheme's **Sales Channel** matches the customer's channel.
3. **Today is within** the scheme's Start–End dates **and** the scheme is **Active**.
4. The customer's **Region / Area / Territory** match the scheme's applicability (or the scheme is
   "Apply to all" for that level).
5. The customer's **Outlet Category** matches (or "Apply to all Outlet Categories").
6. The scheme has **product membership** — a product group, a category, or it's an Order Value
   scheme (whole order).

### The "Running Schemes" list

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

### Indicators on each product row

- A **ribbon / ⭐ icon** marks products that belong to a running scheme.
- When a scheme actually applies to a line, a **price band** shows the **discounted unit price**
  next to the **original price**, plus a **tag with the scheme name**. A breakup control reveals the
  step-by-step price changes (Base → Free Quantity → QPS → …).

### What each scheme type does to the price (plain language)

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

### The order summary

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

## Appendix — Troubleshooting: "Why isn't my scheme showing?"

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
