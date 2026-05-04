/**
 * @description       : Quick Action wrapper – opens the Form Renderer in read-only mode
 *                      for the current Form Submission record.
 * @author            : Daniel Murracas
 * @last modified on  : 19-03-2026
 * @last modified by  : Daniel Murracas
 * Modifications Log
 * ------------------------------------------------------------
 * Ver   Date         Author              Modification
 * 1.0   19-03-2026   Daniel Murracas     Initial Version
 * ------------------------------------------------------------
**/
import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class FormRendererAction extends LightningElement {
    @api recordId;

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}
