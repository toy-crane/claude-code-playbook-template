import { expect, test } from "@playwright/test";

test("홈 화면이 열리고 Todo 입력창이 보인다", async ({ page }) => {
  await page.goto("/");

  await expect(page).toHaveTitle("Todo");
  await expect(page.getByRole("textbox", { name: "새 할 일" })).toBeVisible();
});

test("Todo를 추가하고 새로고침해도 목록과 완료 상태가 유지된다", async ({ page }) => {
  await page.goto("/");

  const input = page.getByRole("textbox", { name: "새 할 일" });
  await input.fill("우유 사기");
  await input.press("Enter");
  await input.fill("청소하기");
  await input.press("Enter");

  await page.getByRole("checkbox", { name: "청소하기 완료" }).click();

  await page.reload();

  const items = page.getByRole("listitem");
  await expect(items).toHaveCount(2);
  await expect(items.filter({ hasText: "우유 사기" })).toBeVisible();
  await expect(items.filter({ hasText: "청소하기" })).toBeVisible();
  await expect(page.getByRole("checkbox", { name: "청소하기 완료" })).toBeChecked();
  await expect(page.getByRole("checkbox", { name: "우유 사기 완료" })).not.toBeChecked();
});

test("편집 중 Escape를 누르면, 입력 필드가 사라지며 발생하는 blur에도 변경 사항이 저장되지 않는다", async ({
  page,
}) => {
  await page.goto("/");

  const input = page.getByRole("textbox", { name: "새 할 일" });
  await input.fill("우유 사기");
  await input.press("Enter");

  await page.getByText("우유 사기").dblclick();
  const editInput = page.getByRole("textbox", { name: "할 일 수정" });
  await editInput.fill("취소되어야 할 텍스트");
  await editInput.press("Escape");

  await expect(page.getByText("우유 사기", { exact: true })).toBeVisible();
  await expect(page.getByText("취소되어야 할 텍스트")).toHaveCount(0);

  await page.reload();

  await expect(page.getByText("우유 사기", { exact: true })).toBeVisible();
});
