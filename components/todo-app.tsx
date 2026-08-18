"use client";

import { ListChecksIcon, Trash2Icon } from "lucide-react";
import { useEffect, useRef, useState, useSyncExternalStore } from "react";

import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Input } from "@/components/ui/input";
import { createTodo, readTodos, writeTodos, type Todo } from "@/lib/todos";
import { cn } from "@/lib/utils";

// 하이드레이션이 끝났는지만 알려주는 최소 저장소. 서버와 하이드레이션 렌더에서는
// false, 그 뒤로는 true 다. 참조가 매 렌더 바뀌지 않도록 모듈 수준에 둔다.
const subscribeNothing = () => () => {};
const onClient = () => true;
const onServer = () => false;

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

  useEffect(() => {
    if (!hydrated) return;
    writeTodos(todos);
  }, [hydrated, todos]);

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
    setTodos((previous) =>
      previous.map((todo) =>
        todo.id === id ? { ...todo, done: !todo.done } : todo
      )
    );
  }

  function remove(id: string) {
    if (editingId === id) setEditingId(null);
    setTodos((previous) => previous.filter((todo) => todo.id !== id));
  }

  function startEdit(todo: Todo) {
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
                    // 드래그해서 복사하는 것은 그대로 두고, 편집을 여는 두 번째
                    // 클릭이 글자를 선택해 번쩍이는 것만 막는다.
                    if (event.detail > 1) event.preventDefault();
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
                onClick={() => remove(todo.id)}
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
