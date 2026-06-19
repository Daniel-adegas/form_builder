import { tableQuestionHasAnswer } from "c/formTableQuestionUtil";

describe("formTableQuestionUtil", () => {
  describe("tableQuestionHasAnswer", () => {
    it("returns false for null, empty, or empty collections", () => {
      expect(tableQuestionHasAnswer(null)).toBe(false);
      expect(tableQuestionHasAnswer("")).toBe(false);
      expect(tableQuestionHasAnswer("[]")).toBe(false);
      expect(tableQuestionHasAnswer("{}")).toBe(false);
    });

    it("uses default col1/col2 when column config is missing", () => {
      const empty = '[{"id":1,"col1":"","col2":""}]';
      expect(tableQuestionHasAnswer(empty)).toBe(false);

      const filled = '[{"id":1,"col1":"a","col2":""}]';
      expect(tableQuestionHasAnswer(filled)).toBe(true);
    });

    it("maps comma-separated labels to col0, col1 like formQuestionTable", () => {
      const cfg = "Name,Email";
      expect(
        tableQuestionHasAnswer('[{"id":1,"col0":"x","col1":""}]', cfg)
      ).toBe(true);
      expect(
        tableQuestionHasAnswer('[{"id":1,"col0":"","col1":""}]', cfg)
      ).toBe(false);
    });

    it("ignores non-schema keys (no false positives from row metadata)", () => {
      const cfg = "A";
      expect(
        tableQuestionHasAnswer(
          '[{"id":1,"col0":"","rowIndex":0,"_meta":"x"}]',
          cfg
        )
      ).toBe(false);
    });

    it("counts a real column named rowId per schema", () => {
      const cfg = JSON.stringify([
        { label: "Row id label", fieldName: "rowId" }
      ]);
      expect(
        tableQuestionHasAnswer('[{"id":1,"rowId":"user value"}]', cfg)
      ).toBe(true);
      expect(tableQuestionHasAnswer('[{"id":1,"rowId":""}]', cfg)).toBe(false);
    });

    it("supports numeric string field names in schema", () => {
      const cfg = JSON.stringify([{ label: "N", fieldName: "42" }]);
      expect(tableQuestionHasAnswer('[{"id":1,"42":"v"}]', cfg)).toBe(true);
    });

    it("returns true on parse failure only when raw string is non-empty", () => {
      expect(tableQuestionHasAnswer("not-json")).toBe(true);
      expect(tableQuestionHasAnswer("   not-json  ")).toBe(true);
    });
  });
});
