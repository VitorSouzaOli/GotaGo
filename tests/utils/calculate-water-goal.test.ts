import { describe, expect, it } from "vitest";
import { calculateWaterGoal } from "../../src/utils/calculate-water-goal.js";

describe("calculateWaterGoal", () => {
  describe("sem peso válido (meta padrão de 2000ml)", () => {
    it.each([[undefined], [0], [-1], [-70], [NaN]])(
      "retorna 2000ml sem aviso para o peso %s",
      (weight) => {
        const result = calculateWaterGoal(weight);

        expect(result.dailyGoal).toBe(2000);
        expect(result.warning).toBeUndefined();
      },
    );
  });

  describe("piso mínimo de 2000ml", () => {
    it.each([
      [1, "peso muito baixo"],
      [30, "criança"],
      [50, "exemplo do PDF (50kg)"],
      [57, "57kg dá 1995ml, abaixo do piso"],
      [57.142857, "limite exato do piso (2000ml)"],
    ])("peso %s kg vira 2000ml (%s)", (weight) => {
      expect(calculateWaterGoal(weight)).toEqual({ dailyGoal: 2000 });
    });

    it("não aplica o piso quando a conta passa de 2000ml", () => {
      // 57,2 x 35 = 2002
      expect(calculateWaterGoal(57.2).dailyGoal).toBe(2002);
    });
  });

  describe("fórmula de 35ml por kg", () => {
    it.each([
      [60, 2100],
      [70, 2450],
      [80, 2800], // exemplo do PDF
      [90, 3150],
      [100, 3500],
    ])("peso %s kg resulta em %sml", (weight, expected) => {
      expect(calculateWaterGoal(weight)).toEqual({ dailyGoal: expected });
    });
  });

  describe("arredondamento", () => {
    it("arredonda .5 para cima", () => {
      // 70,5 x 35 = 2467,5
      expect(calculateWaterGoal(70.5).dailyGoal).toBe(2468);
      // 80,5 x 35 = 2817,5
      expect(calculateWaterGoal(80.5).dailyGoal).toBe(2818);
    });

    it("arredonda para baixo quando a fração é menor que .5", () => {
      // 90,01 x 35 = 3150,35
      expect(calculateWaterGoal(90.01).dailyGoal).toBe(3150);
    });

    it("sempre devolve um número inteiro", () => {
      for (const weight of [61.37, 72.91, 88.88, 99.99]) {
        expect(Number.isInteger(calculateWaterGoal(weight).dailyGoal)).toBe(true);
      }
    });
  });

  describe("aviso de meta acima de 4000ml", () => {
    it("não avisa com meta de 3990ml (114kg)", () => {
      expect(calculateWaterGoal(114)).toEqual({ dailyGoal: 3990 });
    });

    it("não avisa com meta de exatamente 4000ml (o limite é 'maior que')", () => {
      // 114,29 x 35 = 4000,15 -> arredonda para 4000
      const result = calculateWaterGoal(114.29);

      expect(result.dailyGoal).toBe(4000);
      expect(result.warning).toBeUndefined();
    });

    it("avisa quando a meta passa de 4000ml", () => {
      const result = calculateWaterGoal(114.4); // 4004ml

      expect(result.dailyGoal).toBe(4004);
      expect(result.warning).toContain("4000ml");
      expect(result.warning).toContain("healthcare professional");
    });

    it.each([120, 150, 200])("avisa para %s kg", (weight) => {
      const result = calculateWaterGoal(weight);

      expect(result.dailyGoal).toBe(weight * 35);
      expect(result.warning).toBeDefined();
    });

    it("não perde a meta calculada ao avisar", () => {
      expect(calculateWaterGoal(150)).toMatchObject({ dailyGoal: 5250 });
    });
  });
});
