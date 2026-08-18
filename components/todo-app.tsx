"use client"

import { useEffect, useState } from "react"

import { TodoItem } from "@/components/todo-item"
import { Input } from "@/components/ui/input"
import { loadTodos, saveTodos, type Todo } from "@/lib/todos"

function createId() {
  return typeof crypto !== "undefined" && "randomUUID" in crypto
    ? crypto.randomUUID()
    : Math.random().toString(36).slice(2)
}

export function TodoApp() {
  const [todos, setTodos] = useState<Todo[]>([])
  const [text, setText] = useState("")
  const [editingId, setEditingId] = useState<string | null>(null)

  useEffect(() => {
    // localStorage는 서버에 없는 외부 소스라 마운트 후에만 읽을 수 있다.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setTodos(loadTodos())
  }, [])

  function commit(next: Todo[]) {
    setTodos(next)
    saveTodos(next)
  }

  function handleAdd() {
    const trimmed = text.trim()
    if (!trimmed) return
    commit([{ id: createId(), text: trimmed, completed: false }, ...todos])
    setText("")
  }

  function handleToggle(id: string) {
    commit(todos.map((todo) => (todo.id === id ? { ...todo, completed: !todo.completed } : todo)))
  }

  function handleDelete(id: string) {
    commit(todos.filter((todo) => todo.id !== id))
  }

  function handleCommitEdit(id: string, nextText: string) {
    const trimmed = nextText.trim()
    commit(
      todos.map((todo) => (todo.id === id ? { ...todo, text: trimmed || todo.text } : todo))
    )
    setEditingId(null)
  }

  return (
    <div className="mx-auto flex w-full max-w-md flex-col gap-4 px-4 py-16">
      <h1 className="text-2xl font-semibold text-foreground">Todo</h1>
      <Input
        value={text}
        onValueChange={setText}
        onKeyDown={(event) => {
          if (event.key === "Enter") handleAdd()
        }}
        placeholder="할 일을 입력하고 Enter를 누르세요"
        aria-label="새 할 일"
      />
      {todos.length === 0 ? (
        <p className="text-sm text-muted-foreground">할 일이 없습니다.</p>
      ) : (
        <ul className="flex flex-col gap-2">
          {todos.map((todo) => (
            <TodoItem
              key={todo.id}
              todo={todo}
              isEditing={editingId === todo.id}
              onToggle={() => handleToggle(todo.id)}
              onDelete={() => handleDelete(todo.id)}
              onStartEdit={() => setEditingId(todo.id)}
              onCommitEdit={(nextText) => handleCommitEdit(todo.id, nextText)}
              onCancelEdit={() => setEditingId(null)}
            />
          ))}
        </ul>
      )}
    </div>
  )
}
