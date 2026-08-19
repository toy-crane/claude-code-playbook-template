"use client";

import { ListChecksIcon, Trash2Icon } from "lucide-react";
import type React from "react";
import { useEffect, useRef, useState, useSyncExternalStore } from "react";

import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Input } from "@/components/ui/input";
import { createTodo, readTodos, writeTodos, type Todo } from "@/lib/todos";
import { cn } from "@/lib/utils";

// 하이드레이션이 끝났는지만 알려주는 최소 저장소. 서버와 하이드레이션 렌더에서는
// false, 그 뒤로는 true 다. useSyncExternalStore 는 인자의 참조가 바뀌면 다시
// 구독하므로, 세 함수를 모듈 수준에 두어 매 렌더 같은 참조를 넘긴다.
const subscribeNothing = () => () => {};
const onClient = () => true;
const onServer = () => false;

// 한 번의 클릭인지 더블클릭의 첫 클릭인지 갈리기를 기다리는 시간.
const DOUBLE_CLICK_GRACE_MS = 300;

export function TodoApp() {
  // 서버에는 저장된 목록이 없다. 하이드레이션 렌더까지는 목록도 빈 목록 안내도
  // 그리지 않아 서버 HTML과 정확히 일치시키고, 하이드레이션이 끝난 다음 렌더에서
  // 실제 목록을 그린다. 빈 목록 안내가 스쳤다가 항목으로 바뀌는 일을 막는다.
  const hydrated = useSyncExternalStore(subscribeNothing, onClient, onServer);
  const [todos, setTodos] = useState<Todo[]>(() =>
    typeof window === "undefined" ? [] : readTodos()
  );
  const [draft, setDraft] = useState("");
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editDraft, setEditDraft] = useState("");
  const editRef = useRef<HTMLInputElement>(null);
  const pendingSave = useRef<ReturnType<typeof setTimeout> | null>(null);
  const latestSaveEdit = useRef<() => void>(undefined);

  // 사용자가 조작하기 전에는 저장소를 건드리지 않는다. 마운트 직후에 쓰면
  // 페이지를 열기만 해도 저장된 원본이 정규화된 값으로 덮어써진다.
  const savedTodos = useRef<Todo[] | null>(null);
  useEffect(() => {
    if (!hydrated) return;
    if (savedTodos.current === null) {
      savedTodos.current = todos;
      return;
    }
    if (savedTodos.current === todos) return;
    savedTodos.current = todos;
    writeTodos(todos);
  }, [hydrated, todos]);

  useEffect(() => {
    latestSaveEdit.current = saveEdit;
  });

  useEffect(() => cancelPendingSave, []);

  useEffect(() => {
    const input = editRef.current;
    if (!input) return;
    // 커서를 글자 맨 끝에 둔다.
    input.focus();
    input.setSelectionRange(input.value.length, input.value.length);
  }, [editingId]);

  function add() {
    const text = draft.trim();
    if (!text) return;
    setTodos((previous) => [createTodo(text), ...previous]);
    setDraft("");
  }

  function toggle(id: string) {
    saveEdit();
    setTodos((previous) =>
      previous.map((todo) =>
        todo.id === id ? { ...todo, done: !todo.done } : todo
      )
    );
  }

  function remove(id: string) {
    if (editingId === id) {
      // 저장할 대상이 사라지므로 편집 내용은 남기지 않는다.
      setEditingId(null);
    } else {
      saveEdit();
    }
    setTodos((previous) => previous.filter((todo) => todo.id !== id));
  }

  // 편집 중에 조작 요소를 누르면 편집창이 포커스를 잃는다. 그때 저장이 일어나
  // 글자가 여러 줄로 접히면 행 높이가 커지고, 눌린 요소가 밀려 click 이 도달하지
  // 못한다. 편집 중에만 기본 동작을 막아 포커스를 지키고, 편집 확정은 각 처리기가
  // 직접 한다. 편집 중이 아닐 때는 막지 않아 클릭한 요소가 정상적으로 포커스를 받는다.
  function preventFocusStealWhileEditing(event: React.MouseEvent) {
    if (editingId !== null) event.preventDefault();
  }

  function cancelPendingSave() {
    if (pendingSave.current === null) return;
    clearTimeout(pendingSave.current);
    pendingSave.current = null;
  }

  function startEdit(todo: Todo) {
    cancelPendingSave();
    saveEdit();
    setEditingId(todo.id);
    setEditDraft(todo.text);
  }

  function cancelEdit() {
    setEditingId(null);
  }

  function saveEdit() {
    const id = editingId;
    if (id === null) return;

    const text = editDraft.trim();
    setEditingId(null);
    // 내용을 모두 지운 채 저장하려 하면 원래 내용을 유지한다.
    if (!text) return;

    setTodos((previous) =>
      previous.map((todo) => (todo.id === id ? { ...todo, text } : todo))
    );
  }

  return (
    <main className="mx-auto w-full max-w-[35rem] px-5 pt-8 pb-20 sm:pt-14">
      <h1 className="mb-5 text-2xl leading-tight font-semibold tracking-tight">
        할 일
      </h1>

      <Input
        className="h-11 md:text-[15px]"
        aria-label="새 할 일"
        placeholder="할 일을 입력하고 Enter"
        autoComplete="off"
        value={draft}
        onChange={(event) => setDraft(event.target.value)}
        onKeyDown={(event) => {
          // 한글 등 IME 조합 중의 Enter 는 조합을 확정하는 키다. 이것을 제출로
          // 처리하면 확정된 글자가 입력창에 남아 같은 항목이 두 번 들어간다.
          if (event.key !== "Enter" || event.nativeEvent.isComposing) return;
          event.preventDefault();
          add();
        }}
      />

      {hydrated && (todos.length === 0 ? (
        <div className="flex flex-col items-center gap-3 py-16 text-center">
          <ListChecksIcon
            aria-hidden="true"
            className="size-6.5 text-muted-foreground"
          />
          <p className="text-[15px] font-medium">할 일이 없습니다</p>
          <p className="text-sm leading-relaxed text-muted-foreground">
            위 입력창에 할 일을 적고 Enter를 누르세요.
          </p>
        </div>
      ) : (
        <ul className="mt-2">
          {todos.map((todo) => (
            <li
              key={todo.id}
              className="flex items-start gap-3 border-b border-border py-3.5 last:border-b-0"
            >
              <Checkbox
                className="mt-0.5 size-[18px]"
                checked={todo.done}
                onCheckedChange={() => toggle(todo.id)}
                onMouseDown={preventFocusStealWhileEditing}
                aria-label={todo.text}
              />

              {editingId === todo.id ? (
                <input
                  ref={editRef}
                  className="-my-1 min-w-0 flex-1 rounded-sm border border-ring bg-background px-2 py-0.5 text-base leading-relaxed ring-3 md:text-[15px] ring-ring/50 outline-none"
                  aria-label="할 일 수정"
                  value={editDraft}
                  onChange={(event) => setEditDraft(event.target.value)}
                  onBlur={saveEdit}
                  onKeyDown={(event) => {
                    if (event.nativeEvent.isComposing) return;
                    if (event.key === "Enter") {
                      event.preventDefault();
                      saveEdit();
                    } else if (event.key === "Escape") {
                      event.preventDefault();
                      cancelEdit();
                    }
                  }}
                />
              ) : (
                <span
                  className={cn(
                    "min-w-0 flex-1 cursor-text text-[15px] leading-relaxed wrap-anywhere",
                    todo.done && "text-muted-foreground line-through"
                  )}
                  onMouseDown={(event) => {
                    // 편집 중이 아닐 때는 드래그해서 복사하는 것을 막지 않고,
                    // 편집을 여는 두 번째 클릭의 글자 선택만 막는다.
                    if (editingId !== null || event.detail > 1) {
                      event.preventDefault();
                    }
                  }}
                  onClick={() => {
                    if (editingId === null || editingId === todo.id) return;
                    // 편집 중 바깥을 클릭했으니 저장해야 한다. 다만 이 클릭이
                    // 더블클릭의 첫 클릭이면, 지금 저장해 행 높이가 바뀌는 순간
                    // 두 번째 클릭이 엉뚱한 곳에 떨어진다. 갈릴 때까지 기다린다.
                    cancelPendingSave();
                    pendingSave.current = setTimeout(() => {
                      pendingSave.current = null;
                      latestSaveEdit.current?.();
                    }, DOUBLE_CLICK_GRACE_MS);
                  }}
                  onDoubleClick={() => startEdit(todo)}
                >
                  {todo.text}
                </span>
              )}

              <Button
                variant="ghost"
                size="icon-sm"
                className="-mt-0.5 -mr-1.5 text-muted-foreground hover:text-destructive"
                aria-label={`${todo.text} 삭제`}
                onMouseDown={preventFocusStealWhileEditing}
                onClick={(event) => {
                  // 한 항목을 지우면 아래 항목이 커서 자리로 올라온다. 같은
                  // 더블클릭 제스처의 두 번째 클릭까지 받으면 의도하지 않은
                  // 항목이 사라지고, 되돌릴 방법이 없다.
                  if (event.detail > 1) return;
                  remove(todo.id);
                }}
              >
                <Trash2Icon />
              </Button>
            </li>
          ))}
        </ul>
      ))}
    </main>
  );
}
