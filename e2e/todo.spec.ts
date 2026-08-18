import { expect, test, type Page } from "@playwright/test";

const NEW_TODO = "새 할 일";

async function add(page: Page, text: string) {
  const input = page.getByRole("textbox", { name: NEW_TODO });
  await input.fill(text);
  await input.press("Enter");
}

test.beforeEach(async ({ page }) => {
  await page.goto("/");
  await page.evaluate(() => localStorage.clear());
  await page.reload();
});

test("빈 목록 안내가 보이고, 항목을 추가하면 맨 위에 쌓인다", async ({ page }) => {
  await expect(page).toHaveTitle("할 일");
  await expect(page.getByText("할 일이 없습니다")).toBeVisible();

  await add(page, "장보기");
  await add(page, "우편물 찾기");

  await expect(page.getByText("할 일이 없습니다")).toBeHidden();
  await expect(page.getByRole("listitem")).toHaveText([
    /우편물 찾기/,
    /장보기/,
  ]);
});

test("새로고침해도 목록의 순서와 완료 상태가 유지된다", async ({ page }) => {
  await add(page, "장보기");
  await add(page, "우편물 찾기");
  await page.getByRole("checkbox", { name: "장보기" }).click();

  await page.reload();

  await expect(page.getByRole("listitem")).toHaveText([
    /우편물 찾기/,
    /장보기/,
  ]);
  await expect(page.getByRole("checkbox", { name: "장보기" })).toBeChecked();
  await expect(
    page.getByRole("checkbox", { name: "우편물 찾기" })
  ).not.toBeChecked();
});

test("새로고침 직후 빈 목록 안내가 스쳐 지나가지 않는다", async ({ page }) => {
  await add(page, "장보기");

  const seenEmptyGuide: boolean[] = [];
  await page.reload();
  // 항목이 그려질 때까지, 빈 목록 안내가 한 번이라도 보였는지 계속 확인한다.
  for (let i = 0; i < 40; i += 1) {
    seenEmptyGuide.push(
      await page.getByText("할 일이 없습니다").isVisible().catch(() => false)
    );
    if (await page.getByRole("listitem").first().isVisible().catch(() => false)) {
      break;
    }
  }

  await expect(page.getByRole("listitem")).toHaveText([/장보기/]);
  expect(seenEmptyGuide).not.toContain(true);
});

test("더블클릭으로 편집하고 Enter로 저장하면 새로고침 후에도 남는다", async ({
  page,
}) => {
  await add(page, "장보기");

  await page.getByText("장보기").dblclick();
  const edit = page.getByRole("textbox", { name: "할 일 수정" });
  await expect(edit).toBeFocused();
  await edit.fill("장보기 — 우유와 계란");
  await edit.press("Enter");

  await page.reload();
  await expect(page.getByRole("listitem")).toHaveText([/장보기 — 우유와 계란/]);
});

test("편집 중에 다른 항목의 체크박스를 한 번 누르면 편집 저장과 완료가 함께 일어난다", async ({
  page,
}) => {
  await add(page, "장보기");
  await add(page, "우편물 찾기");

  await page.getByText("우편물 찾기").dblclick();
  await page.getByRole("textbox", { name: "할 일 수정" }).fill("우편물 찾기 오늘");
  await page.getByRole("checkbox", { name: "장보기" }).click();

  await expect(page.getByRole("checkbox", { name: "장보기" })).toBeChecked();
  await expect(page.getByText("우편물 찾기 오늘")).toBeVisible();
});

test("편집 중인 항목의 삭제 버튼을 한 번 누르면 그 항목이 사라진다", async ({
  page,
}) => {
  await add(page, "장보기");
  await add(page, "우편물 찾기");

  await page.getByText("우편물 찾기").dblclick();
  await page.getByRole("textbox", { name: "할 일 수정" }).fill("버려질 편집");
  await page.getByRole("button", { name: "우편물 찾기 삭제" }).click();

  await expect(page.getByRole("listitem")).toHaveText([/장보기/]);
  await expect(page.getByText("버려질 편집")).toBeHidden();
});

test("삭제한 항목은 새로고침 후에도 돌아오지 않는다", async ({ page }) => {
  await add(page, "장보기");
  await add(page, "우편물 찾기");

  await page.getByRole("button", { name: "장보기 삭제" }).click();
  await page.reload();

  await expect(page.getByRole("listitem")).toHaveText([/우편물 찾기/]);
});

test("긴 내용과 공백 없는 URL이 화면을 가로로 밀지 않는다", async ({ page }) => {
  await add(
    page,
    "https://internal.example.com/wiki/onboarding/local-dev-environment-setup-guide-2026-revision-final-v3"
  );

  const overflow = await page.evaluate(
    () => document.documentElement.scrollWidth - window.innerWidth
  );
  expect(overflow).toBeLessThanOrEqual(0);
});
