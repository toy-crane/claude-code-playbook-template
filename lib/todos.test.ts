import { beforeEach, describe, expect, it } from "vitest";

import { loadTodos, saveTodos, type Todo } from "@/lib/todos";

const STORAGE_KEY = "todos";

describe("loadTodos/saveTodos", () => {
  beforeEach(() => {
    window.localStorage.clear();
  });

  it("저장된 값이 없으면 빈 배열을 반환한다", () => {
    expect(loadTodos()).toEqual([]);
  });

  it("저장한 Todo 목록을 그대로 불러온다", () => {
    const todos: Todo[] = [
      { id: "1", text: "우유 사기", completed: false },
      { id: "2", text: "청소하기", completed: true },
    ];

    saveTodos(todos);

    expect(loadTodos()).toEqual(todos);
  });

  it("손상된 JSON이 저장되어 있으면 빈 배열로 시작한다", () => {
    window.localStorage.setItem(STORAGE_KEY, "{not valid json");

    expect(loadTodos()).toEqual([]);
  });

  it("배열이 아닌 값이 저장되어 있으면 빈 배열로 시작한다", () => {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify({ oops: true }));

    expect(loadTodos()).toEqual([]);
  });

  it("형식에 맞지 않는 항목은 걸러낸다", () => {
    window.localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify([
        { id: "1", text: "정상 항목", completed: false },
        { id: "2", text: 123, completed: false },
        { notEven: "a todo" },
      ])
    );

    expect(loadTodos()).toEqual([{ id: "1", text: "정상 항목", completed: false }]);
  });
});
