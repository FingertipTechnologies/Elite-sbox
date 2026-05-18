import { LightningElement, track, api } from 'lwc';
import uploadCreditNotes from '@salesforce/apex/SecondaryNoteUploadController.uploadCreditNotes';
import SAMPLE_CSV from '@salesforce/resourceUrl/SecondaryNoteTemplate';
const HEADERS = ['Customer_Code', 'Credit_Date', 'Amount', 'Reason', 'Description'];
const PREVIEW_LIMIT = 50;

export default class NewCreditNoteDataUpload extends LightningElement {
    @track parsedRows = [];
    @track result = null;
    @track fileName = '';
    @track isUploading = false;
    @track view = 'select'; // 'select' | 'preview' | 'result'

    get isSelectView() { return this.view === 'select'; }
    get isPreviewView() { return this.view === 'preview'; }
    get isResultView() { return this.view === 'result'; }

    get totalRowCount() {
        return this.parsedRows.length;
    }

    get previewDisplayRows() {
        return this.parsedRows.slice(0, PREVIEW_LIMIT).map((r, idx) => ({
            ...r,
            rowKey: 'r' + idx,
            rowNumber: idx + 2
        }));
    }

    get previewDisplayCount() {
        return Math.min(this.parsedRows.length, PREVIEW_LIMIT);
    }

    get hasMoreRows() {
        return this.parsedRows.length > PREVIEW_LIMIT;
    }

    get extraRowCount() {
        return Math.max(0, this.parsedRows.length - PREVIEW_LIMIT);
    }

    get hasErrors() {
        return this.result && this.result.errors && this.result.errors.length > 0;
    }

    get hasSuccesses() {
        return this.result && this.result.successes && this.result.successes.length > 0;
    }

    handleFileChange(event) {
        this.result = null;
        this.parsedRows = [];
        const file = event.target.files && event.target.files[0];
        if (!file) {
            this.fileName = '';
            return;
        }
        const lower = file.name.toLowerCase();
        if (!lower.endsWith('.csv')) {
            this.showToast('error', 'Unsupported file format. Please upload a .csv file.');
            event.target.value = '';
            return;
        }
        this.fileName = file.name;
        const reader = new FileReader();
        reader.onload = () => {
            try {
                const rows = this.parseCsv(reader.result);
                if (rows.length === 0) {
                    this.showToast('error', 'No data rows found in the file.');
                    return;
                }
                this.parsedRows = rows;
                this.view = 'preview';
            } catch (e) {
                this.showToast('error', 'Failed to parse file: ' + e.message);
            }
        };
        reader.onerror = () => {
            this.showToast('error', 'Unable to read the selected file.');
        };
        reader.readAsText(file);
    }

    parseCsv(text) {
        const rows = [];
        const lines = text.split(/\r?\n/).filter(l => l.trim().length > 0);
        if (lines.length === 0) {
            return rows;
        }
        const headers = this.splitCsvLine(lines[0]).map(h => h.trim());
        for (let i = 1; i < lines.length; i++) {
            const cols = this.splitCsvLine(lines[i]);
            const row = {};
            headers.forEach((h, idx) => {
                row[h] = cols[idx] !== undefined ? cols[idx].trim() : '';
            });
            rows.push({
                customerCode: row['Customer_Code'] || row['Customer Code'] || '',
                creditDate: row['Credit_Date'] || row['Credit Date'] || '',
                amount: row['Amount'] || '',
                reason: row['Reason'] || '',
                description: row['Description'] || ''
            });
        }
        return rows;
    }

    splitCsvLine(line) {
        const out = [];
        let cur = '';
        let inQuotes = false;
        for (let i = 0; i < line.length; i++) {
            const ch = line[i];
            if (ch === '"') {
                if (inQuotes && line[i + 1] === '"') {
                    cur += '"';
                    i++;
                } else {
                    inQuotes = !inQuotes;
                }
            } else if (ch === ',' && !inQuotes) {
                out.push(cur);
                cur = '';
            } else {
                cur += ch;
            }
        }
        out.push(cur);
        return out;
    }

    handleUpload() {
        if (this.parsedRows.length === 0) {
            this.showToast('error', 'No rows to upload.');
            return;
        }
        this.isUploading = true;
        this.result = null;
        uploadCreditNotes({ rowsJson: JSON.stringify(this.parsedRows) })
            .then(res => {
                this.result = res;
                this.isUploading = false;
                this.view = 'result';
                if (res.failedCount === 0) {
                    this.showToast('success', `${res.successCount} credit note(s) uploaded successfully.`);
                } else if (res.successCount === 0) {
                    this.showToast('error', `Upload failed for all ${res.failedCount} record(s).`);
                } else {
                    this.showToast('warning', `${res.successCount} succeeded, ${res.failedCount} failed.`);
                }
                this.dispatchEvent(new CustomEvent('uploadcomplete', { detail: res }));
            })
            .catch(error => {
                this.isUploading = false;
                // eslint-disable-next-line no-console
                console.error('Credit note upload error', error);
                const msg = error && error.body && error.body.message ? error.body.message : 'Upload failed.';
                this.result = {
                    totalRecords: this.parsedRows.length,
                    successCount: 0,
                    failedCount: this.parsedRows.length,
                    errors: [{ rowNumber: '-', customerCode: '', noteDate: '', amount: '', reason: '', description: '', message: msg }],
                    successes: []
                };
                this.view = 'result';
                this.showToast('error', msg);
            });
    }

    handleSampleDownload() {
        const link = document.createElement('a');
        link.href = SAMPLE_CSV;
        link.download = 'secondary_credit_note_sample.csv';
        link.style.display = 'none';
        document.body.appendChild(link);
        link.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window }));
        document.body.removeChild(link);
    }

    handleDownloadResult() {
        if (!this.result) {
            this.showToast('error', 'No result available to download.');
            return;
        }

        const header = ['Row No', 'Status', 'Customer Code', 'Customer Name', 'Record Id', 'Credit Note No', 'Credit Date', 'Amount', 'Reason', 'Description', 'Message'];

        const escape = (v) => {
            const str = v == null ? '' : String(v);
            return /[",\n]/.test(str) ? '"' + str.replace(/"/g, '""') + '"' : str;
        };

        const rows = [];
        (this.result.successes || []).forEach(s => {
            rows.push([s.rowNumber, 'Success', s.customerCode || '', s.customerName || '',
                       s.recordId || '', s.recordName || '', s.noteDate || '',
                       s.amount != null ? s.amount : '', '', '', '']);
        });
        (this.result.errors || []).forEach(e => {
            rows.push([e.rowNumber, 'Failed', e.customerCode || '', '', '', '',
                       e.noteDate || '', e.amount || '', e.reason || '', e.description || '',
                       e.message || '']);
        });

        let csvBody = header.join(',') + '\n';
        rows.forEach(row => {
            csvBody += row.map(escape).join(',') + '\n';
        });

        const encodedUri = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csvBody);
        const baseName = this.fileName ? this.fileName.replace(/\.csv$/i, '') : 'credit_note_upload';
        const link = document.createElement('a');
        link.setAttribute('href', encodedUri);
        link.setAttribute('download', baseName + '_result.csv');
        link.click();
    }

    handleBackToSelect() {
        this.parsedRows = [];
        this.result = null;
        this.fileName = '';
        this.view = 'select';
    }

    @api
    reset() {
        this.parsedRows = [];
        this.result = null;
        this.fileName = '';
        this.isUploading = false;
        this.view = 'select';
    }

    handleClose() {
        this.reset();
        this.dispatchEvent(new CustomEvent('close'));
    }

    showToast(variant, message) {
        const toast = this.template.querySelector('c-custom-toast');
        if (toast) {
            toast.showToast(variant, message);
        }
    }
}