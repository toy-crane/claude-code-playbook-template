"use client";

import { ListChecksIcon, Trash2Icon } from "lucide-react";
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

// 편집창과 글자가 같은 상자·같은 방식으로 줄바꿈해야 편집을 확정할 때 행 높이가
// 바뀌지 않는다. 높이가 바뀌면 아래 항목이 밀려 클릭이 엉뚱한 곳에 떨어진다.
// 글자 크기와 줄 높이를 한 유틸리티로 함께 지정한다. text-* 가 자체 줄 높이를
// 실어 leading-* 와 충돌하면 두 상자의 높이가 어긋난다. 좁은 폭에서 16px 인 것은
// 편집창이 16px 미만이면 iOS Safari 가 포커스 시 화면을 확대하기 때문이다.
const TEXT_BOX =
  "min-w-0 flex-1 whitespace-pre-wrap wrap-anywhere text-base/relaxed md:text-[15px]/relaxed";

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
  const editRef = useRef<HTMLTextAreaElement>(null);

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
    const input = editRef.current;
    if (!input) return;
    // 커서를 글자 맨 끝에 둔다.
    input.focus();
    input.setSelectionRange(input.value.length, input.value.length);
  }, [editingId]);

  useEffect(() => {
    const input = editRef.current;
    if (!input) return;

    // 내용에 맞춰 높이를 늘려, 저장했을 때의 글자 높이와 같게 유지한다.
    const fit = () => {
      input.style.height = "auto";
      input.style.height = `${input.scrollHeight}px`;
    };
    fit();

    // 화면 폭이 바뀌면 줄바꿈 위치가 달라진다. 다시 맞추지 않으면 넘친 글자가
    // overflow-hidden 에 가려 보이지도 스크롤되지도 않는다.
    const observer = new ResizeObserver(fit);
    observer.observe(input);
    return () => observer.disconnect();
  }, [editingId, editDraft]);

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

  function startEdit(todo: Todo) {
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
                aria-label={todo.text}
              />

              {editingId === todo.id ? (
                <textarea
                  ref={editRef}
                  rows={1}
                  className={cn(
                    TEXT_BOX,
                    "resize-none overflow-hidden rounded-xs bg-transparent ring-2 ring-ring ring-offset-2 ring-offset-background outline-none"
                  )}
                  aria-label="할 일 수정"
                  value={editDraft}
                  onChange={(event) =>
                    // 할 일은 추가 입력창으로 만들 수 있는 것과 같게 한 줄이다.
                    // 붙여넣기로 들어온 줄바꿈을 그대로 두면 저장 시 다듬어지며
                    // 행 높이가 줄어, 아래 항목을 누르던 클릭이 어긋난다.
                    setEditDraft(event.target.value.replace(/[\r\n\t]+/g, " "))
                  }
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
                    TEXT_BOX,
                    "cursor-text",
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
