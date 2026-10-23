# Keepsy

An iPhone app for keeping track of what's at home and when it runs out: fridge, pantry, bathroom, anywhere.

- Every item counts down to its expiration date, soonest first.
- Scan the date on a package with the camera.
- Swipe when you use something up or buy it again; Keepsy remembers where it goes and how long it lasts.
- A shopping list that suggests what ran out and what you usually buy around now.
- One reminder a day with what expires soon.

Built with SwiftUI and Core Data, iOS 18+. Korean and English.

## Develop

Open `Keepsy.xcodeproj` in Xcode 26 and run the `Keepsy` scheme. In debug builds, launch with `-sampleData` to start with example items.

Run tests:

```sh
xcodebuild test -project Keepsy.xcodeproj -scheme Keepsy -destination 'platform=iOS Simulator,name=iPhone 16'
```

- `design/AppIcon.svg`: app icon source
- `docs/`: privacy policy, published with GitHub Pages
- `store/AppStore.md`: App Store listing drafts

## 진행 상황 (2026-10-23)

**완료**
- 기존 ASP.NET 웹앱을 지우고 SwiftUI iPhone 앱으로 새로 만듦. 저장소 이름 `home_stock` → `Keepsy`.
- 탭 3개: 임박순(검색 "집에 있나?", 긴급도별 구역) / 장소(최대 3단계, 기본 부엌 › 냉장·냉동) / 장보기(다 떨어짐·구매 주기 추천, "집에 넣기").
- 물건 하나에 여러 묶음(기한·수량·잔량 4단계). 밀어서 "다 씀"/"또 샀음", 길게 눌러 잔량·냉동하기·버렸어요.
- 포장지 날짜 카메라 스캔(한국·미국·유럽 형식, 월 이름 포함), 하루 1회 요약 알림.
- 첫 실행 안내 4장, 설정(알림·언어·권한·평가·문의·개인정보·전체 삭제), 개인정보 매니페스트.
- 한국어/영어(영어는 "3 days / Today", 한국어는 D-day). 다크 모드.
- 캐릭터 일러스트 아이콘과 앱 안 그림 5장. 개인정보처리방침 GitHub Pages 공개, 스토어 문구 초안.
- 버림 통계(설정 › 버림 통계: 최근 30일 다 씀·버림·비율, 자주 버리는 것).
- iCloud 동기화(개인 DB), 기기별 기본 장소 중복 자동 정리.
- 테스트 27개 통과.

**남은 일**
- 가족 공유, "곧 만료" 위젯. CloudKit 스키마 Production 배포.
- 출시: 스크린샷, App Store Connect 등록, EU 비판매자 신고. 중국 제외 전 세계.
- 실제 기기에서 날짜 스캔, 장보기·장소·설정 화면 터치 확인.

자세한 기획과 작업 규칙은 `CLAUDE.md`에 있다.
