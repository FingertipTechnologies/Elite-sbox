import { LightningElement, track, api } from 'lwc';
import getOrderItemsForInvoice from '@salesforce/apex/DMSPortalLwc.getOrderItemsForInvoice';
import saveSecondaryInvoiceWithSchemes from '@salesforce/apex/DMSPortalLwc.saveSecondaryInvoiceWithSchemes';

// Fixed display order for schemes by type (applicable scheme list per product + Schemes tab).
const SCHEME_TYPE_RANK = { 'Free Quantity': 1, 'QPS': 2, 'FOC Giveaway': 3, 'Category Value': 4, 'Order Value': 5 };
const schemeTypeRank = (t) => SCHEME_TYPE_RANK[t] || 99;

export default class SecondaryOrders extends LightningElement {
    @api selectedOrderIds;
    @api selectedOrderId;
    @api selectedCustomerName;
    @api selectedCustomerId;

    // Engine state
    @track schemePro = [];        // kept empty; all items live in productData
    @track productData = [];      // all invoice line items (engine items)
    @track coverageSchemes = [];  // running schemes for the account
    @track focLines = [];
    appliedSchemeRecords = [];
    categoryValueDiscount = 0;
    orderValueDiscount = 0;
    orderSchemeProductIds = new Set();

    // Summary totals
    @track subTotalAmt = '0.00';
    @track totalTaxAmt = '0.00';
    @track grandTotalAmt = '0.00';
    @track netPayable = '0.00';
    @track totalQnt = 0;
    @track totalNetWeight = '0.00';
    @track issues = [];

    // Screen + header fields
    @track screen = 'products';   // products | schemes | summary
    @track isSubPartLoad = false;
    remarks = '';
    delivaryRemakrs = '';
    gstNumber = '';
    irnNumber = '';
    beatName = '';
    invoiceDate = new Date().toISOString().split('T')[0];
    _recalcTimer;
    _lastInvalidSig = '';
    @track _expandedSchemes = new Set();
    @track _breakupOpen = new Set();      // product ids whose applied price breakup is open
    @track _applicableOpen = new Set();   // product ids whose applicable scheme list is open
    coverageProductSchemeIds = {};

    connectedCallback() {
        this.loadData();
    }

    loadData() {
        this.isSubPartLoad = true;
        getOrderItemsForInvoice({ orderId: this.selectedOrderId })
            .then(data => {
                this.beatName = data.beatName || '';
                this.gstNumber = data.gstNumber || '';
                this.orderSchemeProductIds = new Set((data.orderSchemeProductIds || []).map(String));
                this.coverageSchemes = (data.coverage && data.coverage.schemes) ? data.coverage.schemes : [];
                this.coverageProductSchemeIds = (data.coverage && data.coverage.productSchemeIds) ? data.coverage.productSchemeIds : {};
                this.productData = (data.items || []).map(it => ({
                    orderItemId: it.orderItemId,
                    id: it.id,
                    name: it.name,
                    value: Number(it.value) || 0,
                    orderedQty: Number(it.orderedQty) || 0,
                    UnitPricePriceBook: Number(it.UnitPricePriceBook) || 0,
                    taxPercent: Number(it.taxPercent) || 0,
                    subGroup: it.subGroup,
                    proCate: it.proCate,
                    netWeight: Number(it.netWeight) || 0,
                    beforeCategorySlabUnitPrice: it.beforeCategorySlabUnitPrice,
                    afterCategorySlabUnitPrice: it.afterCategorySlabUnitPrice,
                    beforeSchemeUnitPrice: Number(it.beforeSchemeUnitPrice) || 0,
                    availableQuantity: Number(it.availableQuantity) || 0
                }));
                this.applySchemeEngine();
                this.isSubPartLoad = false;
            })
            .catch(error => {
                console.error('Error loading order items for invoice:', error);
                this.showToast('Error', 'Failed to load order items', 'error');
                this.isSubPartLoad = false;
            });
    }

    /* ============================ Screen navigation ============================ */
    get isProductsView() { return this.screen === 'products'; }
    get isSchemeView()   { return this.screen === 'schemes'; }
    get isSummaryView()  { return this.screen === 'summary'; }

    get productsTabClass() { return this.screen === 'products' ? 'so-tab so-tab--active' : 'so-tab'; }
    get schemesTabClass()  { return this.screen === 'schemes' ? 'so-tab so-tab--active' : 'so-tab'; }
    get summaryTabClass()  { return this.screen === 'summary' ? 'so-tab so-tab--active' : 'so-tab'; }

    showProducts() { this.screen = 'products'; }
    showSchemes()  { this.screen = 'schemes'; }
    showSummary()  { this.computeIssues(); this.screen = 'summary'; }

    // "Next: Schemes" from the Products screen — validate qty vs available stock before advancing.
    handleNextFromProducts() {
        const offenders = this.productData
            .filter(p => (Number(p.value) || 0) > (Number(p.availableQuantity) || 0))
            .map(p => p.name);
        if (offenders.length) {
            this.showToast('Validation Error',
                'Invoice Qty cannot exceed Available Qty for: ' + offenders.join(', '), 'error');
            return;
        }
        const anyQty = this.productData.some(p => (Number(p.value) || 0) > 0);
        if (!anyQty) {
            this.showToast('Validation Error', 'Add at least one item to invoice.', 'error');
            return;
        }
        this.screen = 'schemes';
    }

    // Schemes screen — per-card expand/collapse (default collapsed).
    toggleScheme(event) {
        const id = String(event.currentTarget.dataset.schemeId);
        if (this._expandedSchemes.has(id)) {
            this._expandedSchemes.delete(id);
        } else {
            this._expandedSchemes.add(id);
        }
        this._expandedSchemes = new Set(this._expandedSchemes); // reactivity
    }

    get displayCoverageSchemes() {
        return (this.coverageSchemes || [])
            .slice()
            .sort((a, b) => schemeTypeRank(a.schemeType) - schemeTypeRank(b.schemeType))
            .map(cs => {
                const isExpanded = this._expandedSchemes.has(String(cs.id));
                return {
                    ...cs,
                    isExpanded,
                    expandIcon: isExpanded ? 'utility:chevrondown' : 'utility:chevronright'
                };
            });
    }

    get hasIssues() { return this.issues && this.issues.length > 0; }
    get hasFocLines() { return this.focLines && this.focLines.length > 0; }
    get hasHeaderDiscounts() {
        return (Number(this.categoryValueDiscount) || 0) > 0 || (Number(this.orderValueDiscount) || 0) > 0;
    }
    get categoryDiscountLabel() { return this._round2(this.categoryValueDiscount).toFixed(2); }
    get orderDiscountLabel() { return this._round2(this.orderValueDiscount).toFixed(2); }

    // Screen-1 cart rows (with display fields layered over engine items)
    get cartItems() {
        const schemeNameById = {};
        const schemeById = {};
        (this.coverageSchemes || []).forEach(s => {
            schemeNameById[String(s.id)] = s.name;
            schemeById[String(s.id)] = s;
        });
        const psm = this.coverageProductSchemeIds || {};
        const breakupOpen = this._breakupOpen || new Set();
        const applicableOpen = this._applicableOpen || new Set();
        // A purely-free FOC giveaway seeds at value 0 and is surfaced only in the Summary (as a ₹0
        // FREE line); hide its empty paid card so it doesn't appear on the Products screen at all.
        const focIds = new Set((this.focLines || []).map(f => String(f.id)));
        return this.productData
            .filter(p => !((Number(p.value) || 0) === 0 && focIds.has(String(p.id))))
            .map((p, idx) => {
            const qty = Number(p.value) || 0;
            const base = Number(p.UnitPricePriceBook) || 0;
            const unit = Number(p.discountedUnitPrice != null ? p.discountedUnitPrice : p.UnitPricePriceBook) || 0;
            const taxAmt = this._round2(unit * qty * (Number(p.taxPercent) || 0) / 100);
            const total = this._round2(unit * qty + taxAmt);
            const pid = String(p.id);

            // Schemes APPLIED to this line (Free Quantity / QPS / FOC Giveaway carry a productId).
            const appliedNames = new Set();
            (this.appliedSchemeRecords || []).forEach(r => {
                if (r.productId && String(r.productId) === pid) {
                    appliedNames.add(schemeNameById[String(r.schemeId)] || r.schemeType);
                }
            });
            const appliedChips = [...appliedNames].map((n, i) => ({ key: 'a-' + idx + '-' + i, name: n }));

            // Schemes this product is covered by (group schemes) — expandable applicable list.
            const coveringSchemes = (psm[p.id] || [])
                .map(id => schemeById[String(id)])
                .filter(Boolean)
                .sort((a, b) => schemeTypeRank(a.schemeType) - schemeTypeRank(b.schemeType));

            const isBreakupExpanded = breakupOpen.has(pid);
            const isApplicableExpanded = applicableOpen.has(pid);

            return {
                ...p,
                rowIndex: idx + 1,
                baseUnitPrice: base.toFixed(2),
                showActual: this._round2(unit) < this._round2(base),
                displayUnit: unit.toFixed(2),
                displayTax: taxAmt.toFixed(2),
                displayTotal: total.toFixed(2),
                appliedChips: appliedChips,
                hasScheme: appliedChips.length > 0,
                priceSteps: Array.isArray(p._priceSteps) ? p._priceSteps : [],
                isBreakupExpanded: isBreakupExpanded,
                breakupIcon: isBreakupExpanded ? 'utility:chevrondown' : 'utility:chevronright',
                coveringSchemes: coveringSchemes,
                coveringCount: coveringSchemes.length,
                hasCoveringSchemes: coveringSchemes.length > 0,
                hasSchemeSection: !!p.appliedScheme || coveringSchemes.length > 0,
                isApplicableExpanded: isApplicableExpanded,
                applicableIcon: isApplicableExpanded ? 'utility:chevrondown' : 'utility:chevronright'
            };
        });
    }

    toggleBreakup(event) {
        const pid = String(event.currentTarget.dataset.productId);
        if (this._breakupOpen.has(pid)) this._breakupOpen.delete(pid); else this._breakupOpen.add(pid);
        this._breakupOpen = new Set(this._breakupOpen);
    }

    toggleApplicable(event) {
        const pid = String(event.currentTarget.dataset.productId);
        if (this._applicableOpen.has(pid)) this._applicableOpen.delete(pid); else this._applicableOpen.add(pid);
        this._applicableOpen = new Set(this._applicableOpen);
    }

    // Screen-3 summary rows
    get summaryItems() {
        const rows = [];
        this.productData.forEach(p => {
            const qty = (Number(p.value) || 0) + (Number(p._focMergeQty) || 0);
            if (qty <= 0) return;
            const unit = Number(p.discountedUnitPrice != null ? p.discountedUnitPrice : p.UnitPricePriceBook) || 0;
            const taxAmt = this._round2(unit * (Number(p.value) || 0) * (Number(p.taxPercent) || 0) / 100);
            const net = this._round2(unit * (Number(p.value) || 0) + taxAmt);
            rows.push({
                key: 'p-' + p.id,
                name: p.name,
                qty: qty,
                focFreeQty: Number(p._focMergeQty) || 0,
                unitPrice: unit.toFixed(2),
                taxAmt: taxAmt.toFixed(2),
                netValue: net.toFixed(2),
                isFOC: false
            });
        });
        (this.focLines || []).forEach(f => {
            rows.push({
                key: 'foc-' + f.id,
                name: f.name,
                qty: Number(f.value) || 0,
                focFreeQty: 0,
                unitPrice: '0.00',
                taxAmt: '0.00',
                netValue: '0.00',
                isFOC: true
            });
        });
        return rows;
    }

    /* ============================ Quantity editing ============================ */
    handleQuantityChange(event) {
        const itemId = event.target.dataset.id;
        let newQty = Number(event.target.value);
        if (isNaN(newQty) || newQty < 0) newQty = 0;
        const item = this.productData.find(p => p.orderItemId === itemId);
        if (!item) return;
        if (item.availableQuantity !== undefined && newQty > item.availableQuantity) {
            this.showToast('Validation Error', "Invoice Qty can't be more than Available Qty.", 'error');
        }
        item.value = newQty;
        this.scheduleRecalc();
    }

    removeItem(event) {
        const itemId = event.currentTarget.dataset.id;
        const item = this.productData.find(p => p.orderItemId === itemId);
        if (!item) return;
        item.value = 0;
        this.scheduleRecalc();
    }

    scheduleRecalc() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        clearTimeout(this._recalcTimer);
        this._recalcTimer = setTimeout(() => { this.applySchemeEngine(); }, 300);
    }

    /* ====================== Scheme engine (copied from productScreen4) ====================== */
    _round2(n) {
        const v = parseFloat(n) || 0;
        return Math.round((v + Number.EPSILON) * 100) / 100;
    }
    _gstMult(item) { return 1 + (parseFloat(item.taxPercent || 0) / 100); }

    _allEngineItems() {
        const out = [];
        (this.schemePro || []).forEach(g => (g.products || []).forEach(p => { if (p) out.push(p); }));
        (this.productData || []).forEach(p => { if (p) out.push(p); });
        return out;
    }
    _groupMembers(scheme) {
        const ids = new Set((scheme.groupProductIds || []).map(String));
        return this._allEngineItems().filter(p => ids.has(String(p.id)) && (parseFloat(p.value) || 0) > 0);
    }
    _pickSlabByQty(slabs, qty) {
        let best = null;
        (slabs || []).forEach(sl => {
            const mn = (sl.qtyMin != null) ? parseFloat(sl.qtyMin) : 0;
            const mx = (sl.qtyMax != null) ? parseFloat(sl.qtyMax) : null;
            if (qty >= mn && (mx == null || qty <= mx)) {
                const bestMn = (best && best.qtyMin != null) ? parseFloat(best.qtyMin) : -1;
                if (!best || mn > bestMn) best = sl;
            }
        });
        return best;
    }
    _pickSlabByValue(slabs, val) {
        let best = null;
        (slabs || []).forEach(sl => {
            const mn = (sl.valMin != null) ? parseFloat(sl.valMin) : 0;
            const mx = (sl.valMax != null) ? parseFloat(sl.valMax) : null;
            if (val >= mn && (mx == null || val <= mx)) {
                const bestMn = (best && best.valMin != null) ? parseFloat(best.valMin) : -1;
                if (!best || mn > bestMn) best = sl;
            }
        });
        return best;
    }
    _flagLine(m, scheme) {
        m.appliedScheme = true;
        if (!m._appliedSchemeId) m._appliedSchemeId = scheme.id;
        m.schemeLabel = scheme.name;
    }
    _addPriceStep(m, label) {
        if (!Array.isArray(m._priceSteps)) m._priceSteps = [];
        m._priceSteps.push({ key: 'step-' + m._priceSteps.length, label: label, price: this._round2(m._wkUnit).toFixed(2) });
    }
    buildSchemeContext() {
        const byType = {
            'Free Quantity': [], 'QPS': [], 'FOC Giveaway': [],
            'Category Value': [], 'Order Value': []
        };
        (this.coverageSchemes || []).forEach(s => {
            if (byType[s.schemeType]) byType[s.schemeType].push(s);
        });
        return { byType, skipped: [] };
    }

    _pass1FreeQuantity(byType) {
        byType['Free Quantity'].forEach(scheme => {
            const members = this._groupMembers(scheme);
            const totalQty = members.reduce((s, m) => s + (parseFloat(m.value) || 0), 0);
            if (totalQty <= 0) return;
            const slab = this._pickSlabByQty(scheme.slabsRaw, totalQty);
            if (!slab || !slab.qtyMin || parseFloat(slab.qtyMin) <= 0 || !slab.freeQty) return;
            const free = Math.floor(totalQty / parseFloat(slab.qtyMin)) * parseFloat(slab.freeQty);
            if (free <= 0) return;
            const factor = totalQty / (totalQty + free);
            members.forEach(m => {
                const before = m._wkUnit;
                m._wkUnit = m._wkUnit * factor;
                this._flagLine(m, scheme);
                this._addPriceStep(m, 'Free Quantity — ' + scheme.name);
                this.appliedSchemeRecords.push({
                    productId: m.id,
                    schemeId: scheme.id, slabId: slab.slabId, schemeType: 'Free Quantity',
                    freeQty: free, benefitAmount: this._round2((this._round2(before) - this._round2(m._wkUnit)) * (parseFloat(m.value) || 0)),
                    sequence: slab.seq,
                    description: 'Free Quantity: ' + free + ' EA free on ' + totalQty + ' EA'
                });
            });
        });
    }
    _pass2QPS(byType) {
        byType['QPS'].forEach(scheme => {
            const members = this._groupMembers(scheme);
            const totalQty = members.reduce((s, m) => s + (parseFloat(m.value) || 0), 0);
            if (totalQty <= 0) return;
            const slab = this._pickSlabByQty(scheme.slabsRaw, totalQty);
            if (!slab || slab.benefitAmtPerEA == null) return;
            const off = parseFloat(slab.benefitAmtPerEA);
            members.forEach(m => {
                const before = m._wkUnit;
                m._wkUnit = Math.max(0, m._wkUnit - off);
                this._flagLine(m, scheme);
                this._addPriceStep(m, 'QPS — ' + scheme.name);
                this.appliedSchemeRecords.push({
                    productId: m.id,
                    schemeId: scheme.id, slabId: slab.slabId, schemeType: 'QPS',
                    benefitAmount: this._round2((this._round2(before) - this._round2(m._wkUnit)) * (parseFloat(m.value) || 0)),
                    sequence: slab.seq,
                    description: 'QPS: ₹' + off + ' off per EA'
                });
            });
        });
    }
    _pass3FOCGiveaway(byType) {
        byType['FOC Giveaway'].forEach(scheme => {
            const members = this._groupMembers(scheme);
            const totalQty = members.reduce((s, m) => s + (parseFloat(m.value) || 0), 0);
            if (totalQty <= 0) return;
            const slab = this._pickSlabByQty(scheme.slabsRaw, totalQty);
            if (!slab || !slab.qtyMin || parseFloat(slab.qtyMin) <= 0 || !slab.freeQty || !slab.focProductId) return;
            const focQty = Math.floor(totalQty / parseFloat(slab.qtyMin)) * parseFloat(slab.freeQty);
            if (focQty <= 0) return;
            const focPrice = parseFloat(slab.focUnitPrice) || 0;
            const focTax = parseFloat(slab.focTaxPercent) || 0;
            // If the giveaway product is ALSO ordered (paid qty > 0), merge the free units into that
            // paid line (shown as one "+N free" line in the summary). Otherwise it's a purely-free
            // giveaway → its own ₹0 line (summary-only). Mirrors productScreen4._pass3FOCGiveaway.
            const existing = this._allEngineItems().find(p =>
                String(p.id) === String(slab.focProductId) && (parseFloat(p.value) || 0) > 0);
            if (existing) {
                existing._focMergeQty = (existing._focMergeQty || 0) + focQty;
                existing._focMergeDiscount = (existing._focMergeDiscount || 0) + (focPrice * focQty);
                existing.appliedScheme = true;
                existing.schemeLabel = scheme.name;
                if (!existing._appliedSchemeId) existing._appliedSchemeId = scheme.id;
                if (Array.isArray(existing._priceSteps)) {
                    existing._priceSteps.push({ key: 'step-' + existing._priceSteps.length,
                        label: 'FOC Giveaway — ' + focQty + ' EA free',
                        price: this._round2(existing._wkUnit).toFixed(2) });
                }
            } else {
                this.focLines.push({
                    id: slab.focProductId,
                    name: slab.focProductName,
                    isFOC: true,
                    value: focQty,
                    eachQty: focQty,
                    UnitPricePriceBook: focPrice,
                    discountedUnitPrice: focPrice.toFixed(2),
                    taxPercent: focTax,
                    netWeight: 0,
                    _appliedSchemeId: scheme.id,
                    appliedScheme: true,
                    schemeLabel: scheme.name
                });
            }
            this.appliedSchemeRecords.push({
                productId: slab.focProductId,
                schemeId: scheme.id, slabId: slab.slabId, schemeType: 'FOC Giveaway',
                freeQty: focQty, benefitAmount: this._round2(this._round2(focPrice) * focQty),
                focProductId: slab.focProductId, sequence: slab.seq,
                description: 'FOC Giveaway: ' + focQty + ' EA of ' + (slab.focProductName || 'product')
            });
        });
    }
    _pass4CategoryValue(byType) {
        byType['Category Value'].forEach(scheme => {
            const cat = scheme.productCategory;
            if (!cat) return;
            const members = this._allEngineItems().filter(p => p.subGroup === cat && (parseFloat(p.value) || 0) > 0);
            const catVal = this._round2(members.reduce((s, m) =>
                s + (this._round2(m._wkUnit) * (parseFloat(m.value) || 0) * this._gstMult(m)), 0));
            if (catVal <= 0) return;
            const slab = this._pickSlabByValue(scheme.slabsRaw, catVal);
            if (!slab || slab.benefitPercent == null) return;
            const pct = parseFloat(slab.benefitPercent);
            const disc = catVal * pct / 100;
            this.categoryValueDiscount += disc;
            this.appliedSchemeRecords.push({
                schemeId: scheme.id, slabId: slab.slabId, schemeType: 'Category Value',
                discountPercent: pct, benefitAmount: this._round2(disc), sequence: slab.seq,
                description: 'Category Value: ' + pct + '% on ' + cat
            });
        });
    }
    _pass5OrderValue(byType) {
        byType['Order Value'].forEach(scheme => {
            const members = this._allEngineItems().filter(p => (parseFloat(p.value) || 0) > 0);
            const orderVal = this._round2(members.reduce((s, m) =>
                s + (this._round2(m._wkUnit) * (parseFloat(m.value) || 0) * this._gstMult(m)), 0));
            if (orderVal <= 0) return;
            // Order Value applies on the order value AFTER the Category Value discount.
            const netOrderVal = this._round2(orderVal - (this.categoryValueDiscount || 0));
            if (netOrderVal <= 0) return;
            const slab = this._pickSlabByValue(scheme.slabsRaw, netOrderVal);
            if (!slab || slab.benefitPercent == null) return;
            const pct = parseFloat(slab.benefitPercent);
            const disc = netOrderVal * pct / 100;
            this.orderValueDiscount += disc;
            this.appliedSchemeRecords.push({
                schemeId: scheme.id, slabId: slab.slabId, schemeType: 'Order Value',
                discountPercent: pct, benefitAmount: this._round2(disc), sequence: slab.seq,
                description: 'Order Value: ' + pct + '% on order'
            });
        });
    }

    applySchemeEngine() {
        try {
            this._runSchemeEngine();
        } catch (e) {
            console.error('applySchemeEngine failed', e);
            try { this.computeInvoiceTotals(); } catch (ignore) { /* noop */ }
        }
    }

    _runSchemeEngine() {
        const items = this._allEngineItems();
        items.forEach(p => {
            const base = parseFloat(p.UnitPricePriceBook) || 0;
            p._baseUnit = base;
            p._wkUnit = base;
            p.appliedScheme = false;
            p._appliedSchemeId = null;
            p.schemeLabel = null;
            p._focMergeQty = 0;
            p._focMergeDiscount = 0;
            p._lineDiscount = 0;
            p._priceSteps = [{ key: 'base', label: 'Base Price', price: base.toFixed(2) }];
            p.discountedUnitPrice = base.toFixed(2);
            p.discountedPrice = base * (parseFloat(p.value) || 0);
        });
        this.focLines = [];
        this.categoryValueDiscount = 0;
        this.orderValueDiscount = 0;
        this.appliedSchemeRecords = [];

        const ctx = this.buildSchemeContext();
        this._pass1FreeQuantity(ctx.byType);
        this._pass2QPS(ctx.byType);
        this._pass3FOCGiveaway(ctx.byType);
        this._pass4CategoryValue(ctx.byType);
        this._pass5OrderValue(ctx.byType);

        items.forEach(p => {
            const finalUnit = this._round2(p._wkUnit);
            const base2 = this._round2(p._baseUnit);
            const qty = parseFloat(p.value) || 0;
            p.discountedUnitPrice = finalUnit.toFixed(2);
            p.discountedPrice = finalUnit * qty;
            p._lineDiscount = this._round2((base2 - finalUnit) * qty + (p._focMergeDiscount || 0));
            if (finalUnit !== base2 || (p._focMergeQty || 0) > 0) p.appliedScheme = true;
        });
        this.categoryValueDiscount = this._round2(this.categoryValueDiscount);
        this.orderValueDiscount = this._round2(this.orderValueDiscount);

        // Reactivity + totals
        this.productData = [...this.productData];
        this.computeInvoiceTotals();
    }

    computeInvoiceTotals() {
        let sub = 0, tax = 0, qty = 0, weight = 0;
        this.productData.forEach(p => {
            const v = Number(p.value) || 0;
            if (v <= 0) return;
            const unit = Number(p.discountedUnitPrice != null ? p.discountedUnitPrice : p.UnitPricePriceBook) || 0;
            const lineSub = this._round2(unit * v);
            const lineTax = this._round2(unit * v * (Number(p.taxPercent) || 0) / 100);
            sub += lineSub;
            tax += lineTax;
            qty += v + (Number(p._focMergeQty) || 0);
            weight += (Number(p.netWeight) || 0) * v;
        });
        const grand = this._round2(sub + tax);
        const net = this._round2(grand - (Number(this.categoryValueDiscount) || 0) - (Number(this.orderValueDiscount) || 0));
        this.subTotalAmt = this._round2(sub).toFixed(2);
        this.totalTaxAmt = this._round2(tax).toFixed(2);
        this.grandTotalAmt = grand.toFixed(2);
        this.netPayable = net.toFixed(2);
        this.totalQnt = qty;
        this.totalNetWeight = this._round2(weight).toFixed(2);
    }

    // Order had a scheme on this product but it no longer applies at the invoiced qty.
    computeIssues() {
        const appliedProductIds = new Set(
            (this.appliedSchemeRecords || [])
                .filter(r => r.productId)
                .map(r => String(r.productId))
        );
        const issues = [];
        this.productData.forEach(p => {
            const v = Number(p.value) || 0;
            if (!this.orderSchemeProductIds.has(String(p.id))) return;
            if (v > 0 && !appliedProductIds.has(String(p.id))) {
                issues.push({
                    key: 'iss-' + p.id,
                    productName: p.name,
                    reason: 'Scheme no longer qualifies — invoiced ' + v +
                            ' EA (ordered ' + (Number(p.orderedQty) || 0) + ' EA)'
                });
            }
        });
        this.issues = issues;
        return issues;
    }

    /* ============================ Save ============================ */
    handleSave() {
        this.computeIssues();
        const issueByProduct = {};
        this.issues.forEach(i => { issueByProduct[i.key.replace('iss-', '')] = i.reason; });

        const items = [];
        let totalQuantity = 0, totalTax = 0, grandTotal = 0;
        for (const p of this.productData) {
            const v = Number(p.value) || 0;
            if (v <= 0) continue; // removed / not invoiced
            if (p.availableQuantity !== undefined && v > p.availableQuantity) {
                this.showToast('Validation Error',
                    `${p.name}: Invoice Qty can't be more than Available Qty (${p.availableQuantity}).`, 'error');
                return;
            }
            const unit = Number(p.discountedUnitPrice != null ? p.discountedUnitPrice : p.UnitPricePriceBook) || 0;
            const base = Number(p.beforeSchemeUnitPrice != null ? p.beforeSchemeUnitPrice : p.UnitPricePriceBook) || 0;
            const taxAmt = this._round2(unit * v * (Number(p.taxPercent) || 0) / 100);
            const total = this._round2(unit * v + taxAmt);
            const qtyWithFoc = v + (Number(p._focMergeQty) || 0);
            totalQuantity += qtyWithFoc;
            totalTax += taxAmt;
            grandTotal += total;
            const isIssue = Object.prototype.hasOwnProperty.call(issueByProduct, String(p.id));
            items.push({
                sobjectType: 'Secondary_Invoice_Item__c',
                Product__c: p.id,
                Product_Name__c: p.name,
                Quantity__c: qtyWithFoc,
                Unit_Price__c: unit,
                Tax_Amount__c: taxAmt,
                Tax_Percent__c: p.taxPercent,
                Order_Item__c: p.orderItemId,
                Total_Amount__c: total,
                Before_Category_Slab_Unit_Price__c: p.beforeCategorySlabUnitPrice,
                After_Category_Slab_Unit_Price__c: p.afterCategorySlabUnitPrice,
                Before_Scheme_Unit_Price__c: base,
                After_Scheme_Unit_Price__c: unit,
                Scheme_Issue__c: isIssue,
                Scheme_Issue_Reason__c: isIssue ? issueByProduct[String(p.id)] : null
            });
        }

        if (items.length === 0) {
            this.showToast('Validation Error', 'No items to invoice.', 'error');
            return;
        }

        const invoicePayload = {
            sobjectType: 'Secondary_Invoice__c',
            Store__c: this.selectedCustomerId,
            Invoice_Date__c: this.invoiceDate,
            Customer_Name__c: this.selectedCustomerName,
            Status__c: 'Raised',
            Remarks__c: this.remarks,
            Delivery_remarks__c: this.delivaryRemakrs,
            GST_Number__c: this.gstNumber,
            IRN_Number__c: this.irnNumber,
            Order__c: this.selectedOrderId,
            Total_Tax__c: this._round2(totalTax),
            Grand_Total__c: this._round2(grandTotal),
            Total_Quantity__c: totalQuantity,
            Beat_Name__c: this.beatName
        };
        if (!invoicePayload.Store__c || !invoicePayload.Invoice_Date__c) {
            this.showToast('Validation Error', 'Missing required fields: Store or Invoice Date.', 'error');
            return;
        }

        this.isSubPartLoad = true;
        saveSecondaryInvoiceWithSchemes({
            invoices: [invoicePayload],
            items: items,
            appliedSchemesJson: JSON.stringify(this.appliedSchemeRecords || [])
        })
            .then(() => {
                this.isSubPartLoad = false;
                this.showToast('Success', 'Secondary Invoice saved successfully.', 'success');
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => { this.dispatchEvent(new CustomEvent('returncreated')); }, 1000);
            })
            .catch(error => {
                this.isSubPartLoad = false;
                console.error(error);
                this.showToast('Error', error.body?.message || error.message, 'error');
            });
    }

    /* ============================ Header field handlers ============================ */
    onUpdateRemakrs(event) { this.remarks = event.target.value; }
    onUpdateDelivaryRemakrs(event) { this.delivaryRemakrs = event.target.value; }
    onUpdateGstNumber(event) { this.gstNumber = event.target.value; }
    onUpdateIrnNumber(event) { this.irnNumber = event.target.value; }

    handleCancel() { this.dispatchEvent(new CustomEvent('cancel')); }

    showToast(title, message, variant) {
        const toast = this.template.querySelector('c-custom-toast');
        if (toast) {
            toast.showToast(variant, message);
        } else {
            console.error('Custom Toast component not found!', title, message);
        }
    }
}
