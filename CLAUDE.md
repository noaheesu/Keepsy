# Keepsy

집에 있는 물건(냉장고, 찬장, 욕실 등)과 소비기한을 기록하고, 먼저 써야 할 것부터 D-day로 보여주는 iPhone 앱. 상위 `../CLAUDE.md`의 공통 규칙(토큰 절약, SwiftUI 모범 사례)도 함께 따른다.

## 작업 방식
- **새 대화를 시작하면 먼저 "남은 일"을 바탕으로 다음에 할 작업을 추천안과 함께 질문한다.** 사용자가 고르기 전에는 코딩하지 않는다.
- 단계마다 커밋하고 바로 `git push origin main` 한다. 원격: https://github.com/noaheesu/Keepsy (public). 강제 푸시 금지, 원격이 앞서 있으면 rebase.
- 커밋 메시지 끝에 `Co-Authored-By` 줄을 붙인다.
- 변경 후 테스트:
  ```sh
  xcodebuild test -project Keepsy.xcodeproj -scheme Keepsy -destination 'platform=iOS Simulator,OS=18.2,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
  ```
- 화면 확인: 시뮬레이터에 설치 후 `xcrun simctl launch "iPhone 16" com.noahchoi.keepsy -sampleData -onboarded YES -AppleLanguages "(ko)" -AppleLocale ko_KR` 실행 → `xcrun simctl io "iPhone 16" screenshot`.
- 실기기 설치: README "Develop"의 `xcodebuild … -allowProvisioningUpdates` + `xcrun devicectl device install app` (사용자 iPhone 16 Pro "Noah").
- 새 문자열은 `Keepsy/Localizable.xcstrings`에 ko 번역을 직접 추가한다(영어가 원문). 복수형이 필요한 영어 문구는 plural variation을 쓴다.
- 질문할 때는 추천안을 함께 제시한다. 사용자는 "추천"으로 답하는 경우가 많다.

## 구조
- Xcode 26, iOS 18+, Swift 6, iPhone 전용. 폴더 동기화 그룹이라 `Keepsy/`에 파일을 추가하면 자동으로 타깃에 들어간다.
- 저장: Core Data(`Keepsy.xcdatamodeld`) + `NSPersistentCloudKitContainer`. 공유(가족) 때문에 SwiftData 대신 Core Data를 쓴다. CloudKit 개인 DB 동기화 켜짐(컨테이너 `iCloud.com.noahchoi.keepsy`, 팀 `4CAH5282L3`, `Keepsy.entitlements`). 테스트 호스트에서는 꺼짐(서명 없이 돌아서). 기기마다 만든 기본 장소와 같은 이름의 물건은 동기화 후 `mergeDuplicates`가 합친다.
- 가족 공유(`Household.swift`): 집 전체가 CKShare 하나. 저장소 2개(개인 `Keepsy.sqlite`, 공유받은 `Keepsy-shared.sqlite`). 주인 기기는 저장할 때마다 공유 밖의 새 기록을 공유에 넣고(`shareNewObjects`), 참여자 기기는 새 기록을 공유 저장소에 배정한다(`Persistence`의 willSave). 수락하면 내 기록을 공유 저장소로 복사 후 삭제(`moveAll`). 모두 수정 가능, 설정 › 가족과 공유(UICloudSharingController).
- 엔티티: `Location`(최대 3단계 트리, `isFreezer`), `Item`(이름·사진·마지막 장소·기한 간격 `shelfLifeDays`·구매 주기 `restockDays`), `Batch`(장소·기한·수량·잔량 4단계·`needsDateCheck`), `ShoppingEntry`, `UsageEvent`(다 씀/버림 기록).
- 로직은 뷰 밖에 둔다: `BatchDraft`(저장/다시 추가), `Location`(트리, 삭제 시 내용물을 부모로), `Shopping`(추천·집에 넣기), `Reminders`(하루 1회 요약 알림, 14일치 미리 예약), `PackageDate`(포장지 날짜 OCR 파싱, 지역별 일/월 순서), `Expiry`(D-day, 긴급도).
- 위젯 `KeepsyWidget/`: 동기화 저장소를 직접 열지 않고, 앱이 저장·활성화·동기화 때마다 App Group(`group.com.noahchoi.keepsy`) UserDefaults에 쓰는 `WidgetSnapshot`(이름·기한)만 읽는다. `Keepsy/`의 `Expiry.swift`·`WidgetSnapshot.swift`·`Assets.xcassets`·`Localizable.xcstrings`를 위젯 타깃에 같이 넣었다(pbxproj 예외 목록).
- 화면: 탭 3개 [임박순 `ExpiringView` / 장소 `LocationList` / 장보기 `ShoppingView`], 공용 행 `BatchRows`, 편집 `BatchEditor`(`EditorTarget`: new/edit/restock), `SettingsView`, `OnboardingView`, `StoreErrorView`.
- 디자인: 색은 Asset(AccentColor 바질, Overdue 토마토, Soon 마리골드, Fresh 세이지, 다크 모드 포함). D-day 숫자는 `Font.stamp`(heavy + expanded). 일러스트는 `design/illustrations/*.svg` → Asset 이미지(`Image(.fridge).illustration(height:)`), 아이콘 원본 `design/AppIcon.svg`(1024 PNG는 알파 없이 내보냄).
- 문서: `docs/`는 GitHub Pages(https://noaheesu.github.io/Keepsy/privacy), `store/AppStore.md`는 스토어 문구 초안(한/영). 문의 창구는 dev.noahchoi@gmail.com(`AppLinks.support`, mailto). 스토어 Support URL은 Pages 첫 화면.

## 확정된 기획
- 무료, 전 세계 출시(중국 제외), 한국어·영어. 분석/추적 SDK 없음("데이터 수집 안 함").
- 빠르게 소비되는 물건은 지우고 다시 입력하지 않게: 왼쪽 밀기 "다 씀", 오른쪽 밀기 "또 샀음"(지난 정보로 채운 편집 화면), 길게 누르기(잔량/냉동하기/버렸어요), 장보기 "집에 넣기".
- 수량은 기본 숨김("개수 추가"로 표시). 장보기 추천 = 다 떨어짐 + 평소 구매 주기 도래(알림 아님).
- 알림: 하루 1회, 기본 9시, 7일 이내 항목.
- 하지 않기로 한 것: 바코드(나라별 DB 차이), 영수증 OCR, 레시피, 개봉일, 카테고리별 기본 기한, Siri.

## 남은 일
- 출시 전 CloudKit 대시보드에서 스키마를 Production에 배포.
- 두 기기로 실제 동기화, 두 Apple ID로 초대·수락·나가기 확인 못 함.
- 출시: 스크린샷, App Store Connect 등록, EU 판매자 여부(비판매자) 신고.
- 확인 못 한 것: 실제 기기에서 날짜 스캔, 길게 누르기 메뉴·장보기·장소·설정 화면의 터치 동작.
