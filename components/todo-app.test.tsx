import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it } from "vitest";

import { TodoApp } from "@/components/todo-app";

function getNewTodoInput() {
  return screen.getByRole("textbox", { name: "새 할 일" });
}

function addTodo(text: string) {
  const input = getNewTodoInput();
  fireEvent.change(input, { target: { value: text } });
  fireEvent.keyDown(input, { key: "Enter" });
}

describe("TodoApp", () => {
  beforeEach(() => {
    window.localStorage.clear();
  });

  afterEach(() => {
    window.localStorage.clear();
  });

  it("Todo가 없으면 빈 상태 안내를 보여준다", () => {
    render(<TodoApp />);

    expect(screen.getByText("할 일이 없습니다.")).toBeInTheDocument();
  });

  it("입력 후 Enter를 누르면 새 Todo가 목록 맨 위에 추가되고 입력창이 비워진다", () => {
    render(<TodoApp />);

    addTodo("우유 사기");
    addTodo("청소하기");

    const items = screen.getAllByRole("listitem");
    expect(items).toHaveLength(2);
    expect(items[0]).toHaveTextContent("청소하기");
    expect(items[1]).toHaveTextContent("우유 사기");
    expect(getNewTodoInput()).toHaveValue("");
  });

  it("공백만 있는 입력은 Enter를 눌러도 추가되지 않는다", () => {
    render(<TodoApp />);

    addTodo("   ");

    expect(screen.queryAllByRole("listitem")).toHaveLength(0);
    expect(screen.getByText("할 일이 없습니다.")).toBeInTheDocument();
  });

  it("체크박스를 클릭하면 완료 상태가 토글된다", () => {
    render(<TodoApp />);
    addTodo("우유 사기");

    const checkbox = screen.getByRole("checkbox", { name: "우유 사기 완료" });
    expect(checkbox).not.toBeChecked();

    fireEvent.click(checkbox);
    expect(checkbox).toBeChecked();

    fireEvent.click(checkbox);
    expect(checkbox).not.toBeChecked();
  });

  it("삭제 버튼을 클릭하면 해당 항목이 목록에서 사라진다", () => {
    render(<TodoApp />);
    addTodo("우유 사기");
    addTodo("청소하기");

    fireEvent.click(screen.getByRole("button", { name: "청소하기 삭제" }));

    const items = screen.getAllByRole("listitem");
    expect(items).toHaveLength(1);
    expect(items[0]).toHaveTextContent("우유 사기");
  });

  it("더블클릭하면 인라인 편집 필드로 바뀌고, Enter를 누르면 텍스트가 저장된다", () => {
    render(<TodoApp />);
    addTodo("우유 사기");

    fireEvent.doubleClick(screen.getByText("우유 사기"));
    const editInput = screen.getByRole("textbox", { name: "할 일 수정" });
    expect(editInput).toHaveValue("우유 사기");

    fireEvent.change(editInput, { target: { value: "우유 2개 사기" } });
    fireEvent.keyDown(editInput, { key: "Enter" });

    expect(screen.getByText("우유 2개 사기")).toBeInTheDocument();
    expect(screen.queryByRole("textbox", { name: "할 일 수정" })).not.toBeInTheDocument();
  });

  it("편집 중 입력 필드 밖을 클릭(blur)하면 텍스트가 저장된다", () => {
    render(<TodoApp />);
    addTodo("우유 사기");

    fireEvent.doubleClick(screen.getByText("우유 사기"));
    const editInput = screen.getByRole("textbox", { name: "할 일 수정" });
    fireEvent.change(editInput, { target: { value: "우유 2개 사기" } });
    fireEvent.blur(editInput);

    expect(screen.getByText("우유 2개 사기")).toBeInTheDocument();
  });

  it("편집 중 Escape를 누르면 변경 사항을 버리고 원래 텍스트로 되돌아간다", () => {
    render(<TodoApp />);
    addTodo("우유 사기");

    fireEvent.doubleClick(screen.getByText("우유 사기"));
    const editInput = screen.getByRole("textbox", { name: "할 일 수정" });
    fireEvent.change(editInput, { target: { value: "지워질 텍스트" } });
    fireEvent.keyDown(editInput, { key: "Escape" });

    expect(screen.getByText("우유 사기")).toBeInTheDocument();
    expect(screen.queryByText("지워질 텍스트")).not.toBeInTheDocument();
  });

  it("편집 결과가 빈 문자열이면 원래 텍스트를 유지한다", () => {
    render(<TodoApp />);
    addTodo("우유 사기");

    fireEvent.doubleClick(screen.getByText("우유 사기"));
    const editInput = screen.getByRole("textbox", { name: "할 일 수정" });
    fireEvent.change(editInput, { target: { value: "   " } });
    fireEvent.keyDown(editInput, { key: "Enter" });

    expect(screen.getByText("우유 사기")).toBeInTheDocument();
  });

  it("한 번에 하나의 Todo만 편집 모드가 된다", () => {
    render(<TodoApp />);
    addTodo("우유 사기");
    addTodo("청소하기");

    fireEvent.doubleClick(screen.getByText("우유 사기"));
    expect(screen.getAllByRole("textbox", { name: "할 일 수정" })).toHaveLength(1);

    fireEvent.doubleClick(screen.getByText("청소하기"));
    const editInputs = screen.getAllByRole("textbox", { name: "할 일 수정" });
    expect(editInputs).toHaveLength(1);
    expect(editInputs[0]).toHaveValue("청소하기");
  });

  it("새로고침(리마운트) 후에도 목록 상태가 그대로 복원된다", async () => {
    const { unmount } = render(<TodoApp />);
    addTodo("우유 사기");
    fireEvent.click(screen.getByRole("checkbox", { name: "우유 사기 완료" }));
    unmount();

    render(<TodoApp />);

    await waitFor(() => {
      expect(screen.getByRole("checkbox", { name: "우유 사기 완료" })).toBeChecked();
    });
  });
});
