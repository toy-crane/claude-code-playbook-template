import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { createTodo, readTodos, writeTodos, type Todo } from "@/lib/todos";

const STORAGE_KEY = "todo-app.todos";

beforeEach(() => {
  localStorage.clear();
});

afterEach(() => {
  vi.restoreAllMocks();
});

describe("readTodos", () => {
  it("저장한 목록을 순서 그대로 읽는다", () => {
    const todos: Todo[] = [
      { id: "a", text: "장보기", done: false },
      { id: "b", text: "우편물 찾기", done: true },
    ];
    writeTodos(todos);

    expect(readTodos()).toEqual(todos);
  });

  it("저장된 적이 없으면 빈 목록으로 시작한다", () => {
    expect(readTodos()).toEqual([]);
  });

  it("저장된 값이 JSON이 아니면 빈 목록으로 시작한다", () => {
    localStorage.setItem(STORAGE_KEY, "{망가진 값");

    expect(readTodos()).toEqual([]);
  });

  it("저장된 값이 배열이 아니면 빈 목록으로 시작한다", () => {
    localStorage.setItem(STORAGE_KEY, JSON.stringify({ text: "장보기" }));

    expect(readTodos()).toEqual([]);
  });

  it("모양이 맞지 않는 항목은 걸러내고 나머지는 살린다", () => {
    localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify([
        { id: "a", text: "장보기", done: false },
        { id: "b", text: "완료 값이 문자열", done: "true" },
        { text: "id 가 없음", done: false },
        null,
        { id: "c", text: "우편물 찾기", done: true },
      ])
    );

    expect(readTodos()).toEqual([
      { id: "a", text: "장보기", done: false },
      { id: "c", text: "우편물 찾기", done: true },
    ]);
  });

  it("저장소를 읽을 수 없어도 예외를 밖으로 내지 않는다", () => {
    vi.spyOn(Storage.prototype, "getItem").mockImplementation(() => {
      throw new Error("저장소 접근이 차단됨");
    });

    expect(readTodos()).toEqual([]);
  });
});

describe("writeTodos", () => {
  it("저장이 막혀도 예외를 밖으로 내지 않는다", () => {
    vi.spyOn(Storage.prototype, "setItem").mockImplementation(() => {
      throw new Error("QuotaExceededError");
    });

    expect(() => writeTodos([createTodo("장보기")])).not.toThrow();
  });
});

describe("createTodo", () => {
  it("미완료 상태의 항목을 서로 다른 식별자로 만든다", () => {
    const first = createTodo("장보기");
    const second = createTodo("장보기");

    expect(first).toMatchObject({ text: "장보기", done: false });
    expect(first.id).not.toBe(second.id);
  });
});

describe("중복 식별자", () => {
  it("저장값에 같은 id 가 둘이면 첫 항목만 남긴다", () => {
    // 같은 id 가 둘이면 삭제 버튼 한 번에 두 항목이 사라지고 되돌릴 수 없다.
    localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify([
        { id: "a", text: "먼저 온 항목", done: false },
        { id: "a", text: "같은 id 를 쓴 항목", done: true },
        { id: "b", text: "다른 항목", done: false },
      ])
    );

    expect(readTodos()).toEqual([
      { id: "a", text: "먼저 온 항목", done: false },
      { id: "b", text: "다른 항목", done: false },
    ]);
  });

  it("새로 만든 항목의 식별자는 서로 겹치지 않는다", () => {
    const ids = new Set(
      Array.from({ length: 500 }, () => createTodo("장보기").id)
    );

    expect(ids.size).toBe(500);
  });
});
