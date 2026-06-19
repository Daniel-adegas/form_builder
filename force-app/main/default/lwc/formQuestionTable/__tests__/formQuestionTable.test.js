import { createElement } from "@lwc/engine-dom";
import FormQuestionTable from "c/formQuestionTable";

function appendFormQuestionTable(props = {}) {
  const element = createElement("c-form-question-table", {
    is: FormQuestionTable
  });
  Object.assign(element, props);
  document.body.appendChild(element);
  return element;
}

describe("c-form-question-table", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  describe("getValue", () => {
    it("returns a default row when no initialData is provided", () => {
      const element = appendFormQuestionTable();
      const rows = element.getValue();

      expect(Array.isArray(rows)).toBe(true);
      expect(rows).toHaveLength(1);
      expect(rows[0]).toMatchObject({ id: 1, col1: "", col2: "" });
    });

    it("hydrates rows from initialData JSON", () => {
      const element = appendFormQuestionTable({
        initialData: JSON.stringify([
          { id: 1, col1: "Alpha", col2: "Beta" },
          { id: 2, col1: "Gamma", col2: "" }
        ])
      });
      const rows = element.getValue();

      expect(rows).toHaveLength(2);
      expect(rows[0]).toMatchObject({ id: 1, col1: "Alpha", col2: "Beta" });
      expect(rows[1]).toMatchObject({ id: 2, col1: "Gamma", col2: "" });
    });

    it("reflects cell edits after handleCellChange runs", () => {
      const element = appendFormQuestionTable();
      const input = element.shadowRoot.querySelector(
        'lightning-input[data-field="col1"]'
      );
      expect(input).not.toBeNull();

      input.value = "typed value";
      input.dispatchEvent(new CustomEvent("change", { bubbles: true }));

      expect(element.getValue()[0].col1).toBe("typed value");
    });
  });

  describe("flushPendingCellEdits", () => {
    it("is a no-op when disabled", () => {
      const element = appendFormQuestionTable({ disabled: true });
      const handler = jest.fn();
      element.addEventListener("tablechange", handler);

      element.flushPendingCellEdits();

      expect(handler).not.toHaveBeenCalled();
    });

    it("syncs live DOM input values into rows and dispatches tablechange", () => {
      const element = appendFormQuestionTable();
      const handler = jest.fn();
      element.addEventListener("tablechange", handler);

      const inputs = element.shadowRoot.querySelectorAll(
        "tbody lightning-input"
      );
      expect(inputs.length).toBeGreaterThan(0);

      const col1Input = inputs[0];
      col1Input.value = "pending without blur";

      element.flushPendingCellEdits();

      expect(element.getValue()[0].col1).toBe("pending without blur");
      expect(handler).toHaveBeenCalledTimes(1);
      expect(handler.mock.calls[0][0].detail.rows[0].col1).toBe(
        "pending without blur"
      );
    });

    it("does not dispatch tablechange when DOM values already match rows", () => {
      const element = appendFormQuestionTable({
        initialData: JSON.stringify([{ id: 1, col1: "same", col2: "" }])
      });
      const handler = jest.fn();
      element.addEventListener("tablechange", handler);

      const inputs = element.shadowRoot.querySelectorAll(
        "tbody lightning-input"
      );
      inputs[0].value = "same";

      element.flushPendingCellEdits();

      expect(handler).not.toHaveBeenCalled();
    });

    it("does nothing when there are no tbody inputs", () => {
      const element = createElement("c-form-question-table", {
        is: FormQuestionTable
      });
      document.body.appendChild(element);

      const handler = jest.fn();
      element.addEventListener("tablechange", handler);

      element.flushPendingCellEdits();

      expect(handler).not.toHaveBeenCalled();
    });
  });

  describe("tablechange", () => {
    it("dispatches tablechange when a row is added", () => {
      const element = appendFormQuestionTable();
      const handler = jest.fn();
      element.addEventListener("tablechange", handler);

      element.shadowRoot.querySelector("lightning-button").click();

      expect(handler).toHaveBeenCalledTimes(1);
      expect(handler.mock.calls[0][0].detail.rows).toHaveLength(2);
    });
  });
});
