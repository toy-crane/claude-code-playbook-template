import { render, screen } from "@testing-library/react";
import { expect, test } from "vitest";

import Home from "@/app/page";

test("홈 화면은 할 일 목록 화면을 보여준다", () => {
  render(<Home />);

  expect(
    screen.getByRole("heading", { level: 1, name: "할 일" })
  ).toBeInTheDocument();
  expect(screen.getByRole("textbox", { name: "새 할 일" })).toBeInTheDocument();
});
