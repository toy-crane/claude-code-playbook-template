"use client"

import { Trash2 } from "lucide-react"
import { useState } from "react"

import { Button } from "@/components/ui/button"
import { Checkbox } from "@/components/ui/checkbox"
import { Input } from "@/components/ui/input"
import type { Todo } from "@/lib/todos"
import { cn } from "@/lib/utils"

type TodoItemProps = {
  todo: Todo
  isEditing: boolean
  onToggle: () => void
  onDelete: () => void
  onStartEdit: () => void
  onCommitEdit: (text: string) => void
  onCancelEdit: () => void
}

export function TodoItem({
  todo,
  isEditing,
  onToggle,
  onDelete,
  onStartEdit,
  onCommitEdit,
  onCancelEdit,
}: TodoItemProps) {
  const [draft, setDraft] = useState(todo.text)

  function startEditing() {
    setDraft(todo.text)
    onStartEdit()
  }

  function cancelEditing() {
    setDraft(todo.text)
    onCancelEdit()
  }

  return (
    <li className="flex items-center gap-2 rounded-md border border-border px-3 py-2">
      <Checkbox
        checked={todo.completed}
        onCheckedChange={onToggle}
        aria-label={`${todo.text} 완료`}
      />
      {isEditing ? (
        <Input
          autoFocus
          value={draft}
          onValueChange={setDraft}
          onKeyDown={(event) => {
            if (event.key === "Enter") onCommitEdit(draft)
            if (event.key === "Escape") cancelEditing()
          }}
          onBlur={() => onCommitEdit(draft)}
          aria-label="할 일 수정"
          className="flex-1"
        />
      ) : (
        <span
          onDoubleClick={startEditing}
          className={cn(
            "flex-1 text-sm",
            todo.completed && "text-muted-foreground line-through"
          )}
        >
          {todo.text}
        </span>
      )}
      <Button
        type="button"
        variant="ghost"
        size="icon-sm"
        onClick={onDelete}
        aria-label={`${todo.text} 삭제`}
      >
        <Trash2 />
      </Button>
    </li>
  )
}
