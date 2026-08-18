import { render, screen } from "@testing-library/react";
import { test } from "vitest";

import Home from "@/app/page";

test("홈 화면은 Todo 입력창과 빈 목록 안내를 보여준다", () => {
  render(<Home />);

  screen.getByRole("textbox", { name: "새 할 일" });
  screen.getByText("할 일이 없습니다.");
});
