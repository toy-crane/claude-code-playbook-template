import { fireEvent, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { renderToString } from "react-dom/server";
import { beforeEach, expect, test } from "vitest";

import { TodoApp } from "@/components/todo-app";
import { writeTodos } from "@/lib/todos";

beforeEach(() => {
  localStorage.clear();
});

test("입력하고 Enter를 누르면 새 항목이 목록 맨 위에 추가된다", async () => {
  const user = userEvent.setup();
  render(<TodoApp />);

  const input = screen.getByRole("textbox", { name: "새 할 일" });
  await user.type(input, "장보기{Enter}");
  await user.type(input, "우편물 찾기{Enter}");

  const items = screen.getAllByRole("listitem");
  expect(items).toHaveLength(2);
  expect(items[0]).toHaveTextContent("우편물 찾기");
  expect(items[1]).toHaveTextContent("장보기");
  expect(input).toHaveValue("");
});

test("앞뒤 공백은 다듬어 저장하고, 공백만 있으면 추가하지 않는다", async () => {
  const user = userEvent.setup();
  render(<TodoApp />);

  const input = screen.getByRole("textbox", { name: "새 할 일" });
  await user.type(input, "  장보기  {Enter}");
  expect(screen.getByRole("listitem")).toHaveTextContent(/^장보기$/);

  await user.type(input, "   {Enter}");
  expect(screen.getAllByRole("listitem")).toHaveLength(1);
  expect(input).toHaveValue("   ");
});

test("체크박스를 클릭하면 완료로 표시되고, 항목의 자리는 그대로다", async () => {
  const user = userEvent.setup();
  render(<TodoApp />);

  const input = screen.getByRole("textbox", { name: "새 할 일" });
  await user.type(input, "장보기{Enter}");
  await user.type(input, "우편물 찾기{Enter}");

  expect(screen.getByRole("checkbox", { name: "장보기" })).not.toBeChecked();

  await user.click(screen.getByRole("checkbox", { name: "장보기" }));
  expect(screen.getByRole("checkbox", { name: "장보기" })).toBeChecked();

  const items = screen.getAllByRole("listitem");
  expect(items[0]).toHaveTextContent("우편물 찾기");
  expect(items[1]).toHaveTextContent("장보기");

  await user.click(screen.getByRole("checkbox", { name: "장보기" }));
  expect(screen.getByRole("checkbox", { name: "장보기" })).not.toBeChecked();
});

test("삭제 버튼을 클릭하면 그 항목만 목록에서 사라진다", async () => {
  const user = userEvent.setup();
  render(<TodoApp />);

  const input = screen.getByRole("textbox", { name: "새 할 일" });
  await user.type(input, "장보기{Enter}");
  await user.type(input, "우편물 찾기{Enter}");
  await user.click(screen.getByRole("checkbox", { name: "장보기" }));

  await user.click(screen.getByRole("button", { name: "우편물 찾기 삭제" }));

  expect(screen.queryByText("우편물 찾기")).not.toBeInTheDocument();
  expect(screen.getAllByRole("listitem")).toHaveLength(1);
  expect(screen.getByRole("checkbox", { name: "장보기" })).toBeChecked();
});

test("항목을 더블클릭하면 커서가 맨 끝에 놓인 편집창이 열리고 Enter로 저장된다", async () => {
  const user = userEvent.setup();
  render(<TodoApp />);

  await user.type(screen.getByRole("textbox", { name: "새 할 일" }), "장보기{Enter}");
  await user.dblClick(screen.getByText("장보기"));

  const edit = screen.getByRole("textbox", { name: "할 일 수정" }) as HTMLInputElement;
  expect(edit).toHaveValue("장보기");
  expect(edit).toHaveFocus();
  expect(edit.selectionStart).toBe("장보기".length);

  await user.type(edit, " 우유{Enter}");

  expect(screen.getByText("장보기 우유")).toBeInTheDocument();
  expect(
    screen.queryByRole("textbox", { name: "할 일 수정" })
  ).not.toBeInTheDocument();
});

test("편집 중 Escape를 누르면 고친 내용이 버려진다", async () => {
  const user = userEvent.setup();
  render(<TodoApp />);

  await user.type(screen.getByRole("textbox", { name: "새 할 일" }), "장보기{Enter}");
  await user.dblClick(screen.getByText("장보기"));
  await user.type(screen.getByRole("textbox", { name: "할 일 수정" }), " 우유{Escape}");

  expect(screen.getByText("장보기")).toBeInTheDocument();
  expect(screen.queryByText("장보기 우유")).not.toBeInTheDocument();
  expect(
    screen.queryByRole("textbox", { name: "할 일 수정" })
  ).not.toBeInTheDocument();
});

test("편집 중 바깥을 클릭하면 고친 내용이 저장된다", async () => {
  const user = userEvent.setup();
  render(<TodoApp />);

  await user.type(screen.getByRole("textbox", { name: "새 할 일" }), "장보기{Enter}");
  await user.dblClick(screen.getByText("장보기"));
  await user.type(screen.getByRole("textbox", { name: "할 일 수정" }), " 우유");
  await user.click(screen.getByRole("heading", { level: 1 }));

  expect(screen.getByText("장보기 우유")).toBeInTheDocument();
  expect(
    screen.queryByRole("textbox", { name: "할 일 수정" })
  ).not.toBeInTheDocument();
});

test("편집 중 내용을 모두 지우고 저장하면 원래 내용이 유지되고 항목도 남는다", async () => {
  const user = userEvent.setup();
  render(<TodoApp />);

  await user.type(screen.getByRole("textbox", { name: "새 할 일" }), "장보기{Enter}");
  await user.dblClick(screen.getByText("장보기"));
  await user.clear(screen.getByRole("textbox", { name: "할 일 수정" }));
  await user.type(screen.getByRole("textbox", { name: "할 일 수정" }), "   {Enter}");

  expect(screen.getByText("장보기")).toBeInTheDocument();
  expect(screen.getAllByRole("listitem")).toHaveLength(1);
});

test("완료로 표시된 항목도 편집할 수 있고, 편집해도 완료 상태는 유지된다", async () => {
  const user = userEvent.setup();
  render(<TodoApp />);

  await user.type(screen.getByRole("textbox", { name: "새 할 일" }), "장보기{Enter}");
  await user.click(screen.getByRole("checkbox", { name: "장보기" }));

  await user.dblClick(screen.getByText("장보기"));
  await user.type(screen.getByRole("textbox", { name: "할 일 수정" }), " 우유{Enter}");

  expect(screen.getByRole("checkbox", { name: "장보기 우유" })).toBeChecked();
});

test("편집 중에 체크박스나 삭제 버튼을 눌러도 한 번의 클릭으로 동작한다", async () => {
  const user = userEvent.setup();
  render(<TodoApp />);

  const input = screen.getByRole("textbox", { name: "새 할 일" });
  await user.type(input, "장보기{Enter}");
  await user.type(input, "우편물 찾기{Enter}");

  // 다른 항목의 체크박스: 편집 내용이 저장되고 그 항목도 토글된다.
  await user.dblClick(screen.getByText("우편물 찾기"));
  await user.type(screen.getByRole("textbox", { name: "할 일 수정" }), " 오늘");
  await user.click(screen.getByRole("checkbox", { name: "장보기" }));

  expect(screen.getByRole("checkbox", { name: "장보기" })).toBeChecked();
  expect(screen.getByText("우편물 찾기 오늘")).toBeInTheDocument();

  // 편집 중인 항목 자신의 삭제 버튼: 그 항목이 사라진다.
  await user.dblClick(screen.getByText("우편물 찾기 오늘"));
  await user.type(screen.getByRole("textbox", { name: "할 일 수정" }), " 버려짐");
  await user.click(screen.getByRole("button", { name: "우편물 찾기 오늘 삭제" }));

  expect(screen.queryByText(/우편물/)).not.toBeInTheDocument();
  expect(screen.getAllByRole("listitem")).toHaveLength(1);
});

test("추가하고 완료한 항목은 화면을 다시 열어도 순서와 상태가 유지된다", async () => {
  const user = userEvent.setup();
  const first = render(<TodoApp />);

  const input = screen.getByRole("textbox", { name: "새 할 일" });
  await user.type(input, "장보기{Enter}");
  await user.type(input, "우편물 찾기{Enter}");
  await user.click(screen.getByRole("checkbox", { name: "장보기" }));
  first.unmount();

  render(<TodoApp />);

  expect(await screen.findByRole("checkbox", { name: "장보기" })).toBeChecked();
  expect(screen.getByRole("checkbox", { name: "우편물 찾기" })).not.toBeChecked();
  const items = screen.getAllByRole("listitem");
  expect(items[0]).toHaveTextContent("우편물 찾기");
  expect(items[1]).toHaveTextContent("장보기");
});

test("항목이 없으면 빈 목록 안내가 보이고, 추가하면 사라진다", async () => {
  const user = userEvent.setup();
  render(<TodoApp />);

  expect(await screen.findByText("할 일이 없습니다")).toBeInTheDocument();

  await user.type(screen.getByRole("textbox", { name: "새 할 일" }), "장보기{Enter}");
  expect(screen.queryByText("할 일이 없습니다")).not.toBeInTheDocument();

  await user.click(screen.getByRole("button", { name: "장보기 삭제" }));
  expect(screen.getByText("할 일이 없습니다")).toBeInTheDocument();
});

test("서버가 그린 첫 HTML에는 목록도 빈 목록 안내도 들어 있지 않다", () => {
  // 저장된 목록은 브라우저에서만 읽을 수 있다. 서버 HTML이 둘 중 하나를 미리
  // 그려 두면 새로고침 직후 잘못된 상태가 스쳐 보인다.
  writeTodos([{ id: "a", text: "장보기", done: false }]);

  const html = renderToString(<TodoApp />);

  expect(html).toContain("할 일");
  expect(html).not.toContain("할 일이 없습니다");
  expect(html).not.toContain("장보기");
});

test("편집 중에도 체크박스와 삭제 버튼이 항목 이름을 유지한다", async () => {
  const user = userEvent.setup();
  render(<TodoApp />);

  await user.type(screen.getByRole("textbox", { name: "새 할 일" }), "장보기{Enter}");
  await user.dblClick(screen.getByText("장보기"));

  // 편집창이 열려도 이름 없는 조작 요소가 남으면 안 된다.
  expect(screen.getByRole("checkbox", { name: "장보기" })).toBeInTheDocument();
  expect(screen.getByRole("button", { name: "장보기 삭제" })).toBeInTheDocument();
});

test("한글 조합을 확정하는 Enter로는 항목이 추가되지 않는다", async () => {
  const user = userEvent.setup();
  render(<TodoApp />);

  const input = screen.getByRole("textbox", { name: "새 할 일" });
  await user.type(input, "장보기");

  // IME 조합 중의 Enter는 조합을 확정하는 키다. 이것으로 추가하면 확정된 글자가
  // 입력창에 남아, 사용자가 Enter를 한 번 더 눌러 같은 항목이 두 번 들어간다.
  fireEvent.keyDown(input, { key: "Enter", isComposing: true });
  expect(screen.queryByRole("listitem")).not.toBeInTheDocument();
  expect(input).toHaveValue("장보기");

  // 조합이 끝난 뒤의 Enter는 추가한다.
  fireEvent.keyDown(input, { key: "Enter" });
  expect(screen.getByRole("listitem")).toHaveTextContent("장보기");
});

test("isComposing 을 채우지 않는 브라우저의 조합 확정 Enter 도 걸러낸다", async () => {
  const user = userEvent.setup();
  render(<TodoApp />);

  const input = screen.getByRole("textbox", { name: "새 할 일" });
  await user.type(input, "장보기");

  // 일부 브라우저는 조합 중임을 keyCode 229 로만 알린다.
  fireEvent.keyDown(input, { key: "Enter", keyCode: 229 });
  expect(screen.queryByRole("listitem")).not.toBeInTheDocument();

  fireEvent.keyDown(input, { key: "Enter" });
  expect(screen.getByRole("listitem")).toHaveTextContent("장보기");
});
