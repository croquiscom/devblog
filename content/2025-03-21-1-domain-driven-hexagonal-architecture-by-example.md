---
title: '코드 사례로 보는 Domain-Driven 헥사고날 아키텍처'
tags: []
date: 2025-03-21T01:00:00
author: Robin(김남욱)
---

안녕하세요. 지그재그 서비스팀 로빈입니다.🙂
오늘은 저희 팀에서 관리하고 있는 상품상세페이지(Product Detail Page. 이하 PDP) 서비스의 프로젝트 아키텍처에 대해 간단히 소개해보려고 합니다.

PDP 서비스는 2024년부터 "Domain-Driven 헥사고날 아키텍처"의 프로젝트 구조를 띠고 있는데요, 이렇게 운영한지 어느덧 1년을 향해 가고 있습니다.
국내외 여러 테크 블로그들을 돌아다녀보면 헥사고날 아키텍처란 무엇인지, DDD와 애그리거트는 무엇인지, 이미 그 개념들에 대해 충분히 잘 설명된 자료들을 접할 수 있습니다.
그래서 이 글에서는 아키텍처와 디자인 패턴에 대한 개념 설명보다는 실제 운영 경험을 통해 장점으로 느꼈던 부분들을 코드 예시와 함께 소개해볼까합니다.

<!--more-->

## PDP 프로젝트의 아키텍처

우선 아키텍처 구조가 어떻게 되어있는지 그림으로 표현해보겠습니다.

![1.png](/img/content/2025-03-21-1/1.png)

- 헥사고날 아키텍처의 핵심이 되는 인터페이스 Port 와 구현체인 Adapter 가 존재합니다.
- Hexagon 의 중심인 도메인 서비스 로직쪽에서는 Use Case 로 정보를 주고 받는 행위들이 존재합니다. Use Case 는 인터페이스로 되어있으며 이를 실제로 구현하는 Service 클래스가 존재합니다.
- 실제 도메인 객체를 핸들링할때는 상위에 애그리거트 루트를 두어 그룹화하여 관리합니다.

여러 전시 지면 중에서도 특히 PDP 는 하나의 페이지에 여러 마이크로서비스에서 제공하는 수많은 정보들을 가져와 노출해야하므로 도메인 객체를 그대로 사용하지 않고 DDD 에서 중요한 개념인 애그리거트 모델을 접목하여 그룹핑하여 관리하는 것이 특징입니다.
PDP는 단순히 상품 정보를 표시하는 페이지가 아니라, 약 20여 개의 마이크로서비스와 실시간으로 데이터를 주고받으며 사용자에게 필요한 정보를 최적의 형태로 가공해 제공해야 합니다.
따라서 가장 우선적으로 도메인 로직에 대한 불필요한 변경을 최소화하려는 목표가 있으며 이때 중요하게 생각한 키워드가 인터페이스(Port & Use Case)와 애그리거트입니다.

이제 코드 예시가 있는 본론으로 가보겠습니다.

## Q1. "애그리거트 모델이 접목된 헥사고날 아키텍처의 코드는 어떻게 생겼나요?"

아래 코드는 PDP 를 렌더링하기 위해 UI Component 목록을 반환하는 서버 API 의 일부 예시입니다.
헥사고날 아키텍처에서 Port 와 Use Case 가 어떻게 동작하는지 코드 플로우를 통해 확인할 수 있습니다.
외부 요청을 받았을 때 Controller → Input Port → Domain → Output Port 흐름으로 진행되며, 응답 플로우 또한 다시 역방향으로 진행됩니다.

- #1. Controller (진입점)

  ```kotlin
  @RestController
  @RequestMapping("/pdp")
  class PdpController(
      @Qualifier("pdpPageAdapter") private val pdpPagePort: PdpPagePort,
  ) {
      @GetMapping("/{productId}")
      fun getPdpPage(@PathVariable productId: Long): PdpPage = runBlocking {
          pdpPagePort.generatePage(productId)
      }
  }
  ```

- #2. Driving Adapter (Input Port 의 구현체)

  ```kotlin
  @Service
  class PdpPageAdapter(
      private val pdpAggUseCase: PdpAggUseCase,
      private val pageUseCase: PdpPageUseCase,
      private val lineMarginUseCase: LineMarginUseCase,
  ): PdpPagePort {
      override suspend fun generatePage(productId: Long): PdpPage = coroutineScope {
          // Step 1. 애그리거트(Aggregate) 루트 객체 생성
          val pdpAgg = pdpAggUseCase.getPdpAgg(productId)

          // Step 2. Server-Driven UI 컴포넌트 생성 및 배치
          val page = pageUseCase.generatePage(pdpAgg)

          // Step 3. 생성된 UI 컴포넌트들을 기준으로 컴포넌트 간 라인과 마진을 적용한다.
          val prettyPage = lineMarginUseCase.applyLineAndMargin(page)

          return@coroutineScope prettyPage
      }
  }
  ```

- #3. Domain Use Case (애그리거트 루트를 획득하는 과정)

  ```kotlin
  @Service
  class PdpAggService(
      private val catalogAggUseCase: CatalogAggUseCase,
      private val shopAggUseCase: ShopAggUseCase,
      private val priceAggUseCase: PriceAggUseCase,
      private val reviewAggUseCase: ReviewAggUseCase,
      private val contentAggUseCase: ContentAggUseCase
  ): PdpAggUseCase {
      override suspend fun getPdpAgg(productId: Long): PdpAgg = coroutineScope {
          val catalogAggDeferred = async { catalogAggUseCase.getCatalogAgg(productId) }
          val shopAggDeferred = async { shopAggUseCase.getShopAgg(productId) }
          val priceAggDeferred = async { priceAggUseCase.getPriceAgg(productId) }
          val reviewAggDeferred = async { reviewAggUseCase.getReviewAgg(productId) }
          val contentAggDeferred = async { contentAggUseCase.getContentAgg(productId) } // 이쪽 코드를 대상으로 조금 더 자세히 들여다보겠습니다.

          PdpAgg(
              id = productId,
              catalogAgg = catalogAggDeferred.await(),
              shopAgg = shopAggDeferred.await(),
              priceAgg = priceAggDeferred.await(),
              reviewAgg = reviewAggDeferred.await(),
              contentAgg = contentAggDeferred.await()
          )
      }
  }
  ```

- #4. Domain Use Case (하위 애그리거트를 획득하는 과정)

  > Notes: PDP 컨텐츠에는 여러 정보들이 있겠지만 `PDP 배너 정보`를 가져오는 예시 하나만 나열하였습니다.

  ```kotlin
  @Service
  class ContentAggService(
      @Qualifier("pdpBannerPrimaryAdapter") private val bannerPort: PdpBannerQueryPort
  ): ContentAggUseCase {
      override fun getContentAgg(productId: Long): ContentAgg {
          val banners = bannerPort.findByProductId(productId)
          return ContentAgg(pdpBanners = banners.toDomainObject())
      }
  }
  ```

- #5. Driven Adapter (Output Port 의 구현체)

  ```kotlin
  // 공통 Query Port
  interface QueryPort<T> {
      fun findByProductId(productId: Long): List<T>?
  }

  // 공통 Command Port
  interface CommandPort<T> {
      fun save(productId: Long, data: List<T>)
  }

  // 배너 조회 Output Port
  interface PdpBannerQueryPort : QueryPort<PdpBanner>

  // 배너 저장 Output Port
  interface PdpBannerCommandPort : CommandPort<PdpBanner>

  // Redis 를 통해 정보를 조회하거나 저장하는 output port 구현체
  @Component
  class PdpBannerRedisAdapter(private val redisTemplate: RedisTemplate<String, List<PdpBanner>>) : PdpBannerQueryPort, PdpBannerCommandPort {
      override fun findByProductId(productId: Long): List<PdpBanner>? {
          return redisTemplate.opsForValue().get("pdp-banner:$productId")
      }

      override fun save(productId: Long, banners: List<PdpBanner>) {
          redisTemplate.opsForValue().set("pdp-banner:$productId", banners)
      }
  }

  // 외부 API 호출을 통해 정보를 조회하는 output port 구현체
  @Component
  class PdpBannerApiAdapter(private val webClient: WebClient) : PdpBannerPort {
      override fun findByProductId(productId: Long): List<PdpBanner>? {
          return webClient.get()
              .uri("https://external-api.com/content/$productId/banners")
              .retrieve()
              .bodyToMono(object : ParameterizedTypeReference<List<PdpBanner>>() {})
              .block()
      }
  }

  // Redis 캐시 -> 외부 API 호출 순서로 값을 취하는 output port 구현체
  @Component
  class PdpBannerPrimaryAdapter(
      @Qualifier("pdpBannerRedisAdapter") private val redisQueryPort: PdpBannerQueryPort,
      @Qualifier("pdpBannerRedisAdapter") private val redisCommandPort: PdpBannerCommandPort,
      @Qualifier("pdpBannerApiAdapter") private val apiQueryPort: PdpBannerQueryPort
  ) : PdpBannerQueryPort {
      override fun findByProductId(productId: Long): List<PdpBanner>? {
          return redisQueryPort.findByProductId(productId) // Redis 조회
              ?: apiQueryPort.findByProductId(productId)?.also { // Redis에 없을 때, API 호출
                  if (it.isNotEmpty()) {
                      redisCommandPort.save(productId, it) // API 데이터를 Redis에 저장
                  }
              }
      }
  }

  /*
   * Notes : PrimaryAdapter 의 경우 외부 호출에 대한 우선 순위 결정 로직이 들어가있으므로 이러한 경우, OutputPort 가 아닌 UseCase 를 통한 Service 클래스에서 처리해도 무방합니다.
   */
  ```

PDP 서버는 UI 서버드리븐 처리를 위해 다음과 같이 크게 세번의 동기적/순차적인 스텝을 거치는데요.

- Step 1. 애그리거트(Aggregate) 루트 객체 생성
- Step 2. Server-Driven UI 컴포넌트 생성 및 배치
- Step 3. 생성된 UI 컴포넌트들을 기준으로 컴포넌트 간 라인과 마진을 적용

위 예시로 든 코드의 경우 도메인 모델 즉, 애그리거트 루트를 획득하는 Step 1 과정 중심으로 코드 예시를 보았습니다.

이제 위 코드를 기준으로 하여 헥사고날 아키텍처에서 어떠한 이점들이 있는지 하나씩 살펴보겠습니다. 🙂

## Q2. "헥사고날 아키텍처를 쓰면 무슨 장점이 있어요?"

헥사고날 아키텍처로 운영하면 상대적으로 얻는 이점들이 있습니다

**첫째, 비즈니스 로직이 외부 호출과 명확히 분리되어 있어서, 코드 유지보수가 절감되며 도메인 로직이 보호됩니다.**

**둘째, 코드 확장이 용이합니다.**

**셋째, Mocking 원활해지고 테스트 코드 작성이 용이해집니다.**

이렇게 얘기하면 잘 이해가 안갈 수 있으니 코드 예시로 보겠습니다.

### **이점1) 비즈니스 로직이 외부 호출과 명확히 분리되어 있어서, 코드 유지보수가 절감되며 도메인 로직이 보호됩니다.**

> 요구사항) Redis 조회가 너무 많이 발생하여 이로 인한 비용과 CPU 스로틀링이 크게 발생하고 있습니다. 이를 개선해주세요.

- 코드 예시

  > 위 “**#5. Driven Adapter (Output Port 의 구현체)”** 부분을 보면 Redis 와 외부 API 를 통해 배너 정보를 획득하고 있는 것을 볼 수 있었는데요.
  > Redis 부하 개선 요구사항을 받았다고 가정하고 로컬 캐시를 적용하는 형태로 코드를 개선해보겠습니다.

  ```kotlin
  // Redis 를 통해 정보를 조회하거나 저장하는 output port 구현체
  ..생략..

  // 외부 API 호출을 통해 정보를 조회하는 output port 구현체
  ..생략..

  ////////////
  // 신규 코드
  ////////////
  // 로컬 캐시에 저장된 정보를 조회하거나, 저장하는 output port 구현체
  @Component
  @CacheConfig(cacheNames = ["pdpBanners"]) // 기본 캐시 이름 설정
  class PdpBannerLocalCacheAdapter : PdpBannerQueryPort, PdpBannerCommandPort {

      @Cacheable(key = "#productId")
      override fun findByProductId(productId: Long): List<PdpBanner>? {
          return null // 로컬 캐시가 존재하지 않는 경우에 대한 처리. 캐시가 저장되지 않아야하므로 일반적으로는 null 응답. (또는 @Cacheable 을 사용하지 않고 CacheManager 를 사용하는 것도 가능)
      }

      @CachePut(key = "#productId")
      override fun save(productId: Long, banners: List<PdpBanner>): List<PdpBanner> {
          return banners
      }
  }

  ////////////
  // 변경 코드
  ////////////
  // 로컬 캐시 -> Redis 캐시 -> 외부 API 호출 순서로 값을 취하는 output port 구현체
  @Component
  class PdpBannerPrimaryAdapter(
      @Qualifier("pdpBannerRedisAdapter") private val redisQueryPort: PdpBannerQueryPort,
      @Qualifier("pdpBannerRedisAdapter") private val redisCommandPort: PdpBannerCommandPort,
      @Qualifier("pdpBannerExternalApiAdapter") private val apiQueryPort: PdpBannerQueryPort,
      @Qualifier("pdpBannerLocalCacheAdapter") private val localCacheQueryPort: PdpBannerQueryPort,
      @Qualifier("pdpBannerLocalCacheAdapter") private val localCacheCommandPort: PdpBannerCommandPort
  ) : PdpBannerQueryPort {
      override fun findByProductId(productId: Long): List<PdpBanner>? {
          return localCacheQueryPort.findByProductId(productId) // 1. 로컬 캐시 조회 ----> 이게 추가되었고
              ?: redisQueryPort.findByProductId(productId)?.also { // 2. Redis 조회
                    localCacheCommandPort.save(productId, it) // Redis 데이터가 있다면 로컬 캐시에 저장
                 }
              ?: apiQueryPort.findByProductId(productId)?.also { // 3. API 호출 (로컬 & Redis 모두 없을 때)
                    redisCommandPort.save(productId, it) // API 데이터를 Redis에 저장
                    localCacheCommandPort.save(productId, it) // API 데이터를 로컬 캐시에 저장 ----> 이게 추가되었습니다.
                 }
      }
  }
  ```

  > 위 코드를 보면 알 수 있듯이, 로컬 캐시를 사용하는 Port 하나가 추가되었고 Primary Adapter 로직에서 우선순위 로직만 변경된 것을 알 수 있습니다.
  > 즉, 비즈니스 로직에서의 변경은 전혀 발생하지 않았습니다.

이번에는 다른 예제를 보겠습니다. 다음과 같은 요구사항을 받았다고 가정합니다.

> 요구사항1) 과도한 MSA 로 인한 관리 피로도 및 비용 문제로 인해 일부 서비스를 모놀리식으로 재전환 하려합니다. 이로 인해 External API 대신에 RDB 를 직접 조회해주세요.
>
> 요구사항2) 서버의 확장 전략을 Scale-out 보다는 Scale-up 하는 형태로 변경하려합니다. 레디스 캐시도 비용이니 호출 제거해주세요.

- 코드 예시

  ```kotlin
  // Redis 를 통해 정보를 조회하거나 저장하는 output port 구현체
  => 코드 제거

  // 외부 API 호출을 통해 정보를 조회하는 output port 구현체
  => 코드 제거

  // 로컬 캐시에 저장된 정보를 조회하거나, 저장하는 output port 구현체
  => 유지. 코드 생략

  ////////////
  // 신규 코드
  ////////////
  // RDB 에 저장된 정보를 조회하는 output port 구현체
  @Component
  class PdpBannerMySqlAdapter(private val repository: PdpBannerJpaRepository) : PdpBannerQueryPort {
      override fun findByProductId(productId: Long): List<PdpBanner>? {
          return repository.findByProductId(productId)
      }
  }

  ////////////
  // 변경 코드
  ////////////
  // 로컬 캐시 -> RDB 호출 순서로 값을 취하는 output port 구현체
  @Component
  class PdpBannerPrimaryAdapter(
      @Qualifier("pdpBannerMySqlAdapter") private val mysqlQueryPort: PdpBannerQueryPort,
      @Qualifier("pdpBannerCaffeignAdapter") private val localCacheQueryPort: PdpBannerQueryPort,
      @Qualifier("pdpBannerCaffeignAdapter") private val localCacheCommandPort: PdpBannerCommandPort
  ) : PdpBannerQueryPort {
      override fun findByProductId(productId: Long): List<PdpBanner>? {
          return localCacheQueryPort.findByProductId(productId) // 로컬 캐시 조회
              ?: mysqlQueryPort.findByProductId(productId)?.also { // RDB 조회 (로컬 캐시에 없을 때)
                    localCacheCommandPort.save(productId, it) // 데이터를 로컬 캐시에 저장
              }
      }
  }
  ```

  > 위 코드를 보면 이번에도 마찬가지로 Output Port 에 대한 추가, 삭제만 있었을 뿐 비즈니스 로직 및 도메인 서비스의 변경 사항은 전혀 발생하지 않았습니다.
  > 즉, 도메인 서비스에서는 항상 인터페이스인 Port 를 통해 데이터를 취하고 있기 때문에 외부 호출과 명확하게 분리되어있다고 할 수 있습니다. 이것은 코드 유지보수에도 상당히 긍정적인 영향을 미칩니다.

### **이점2) 코드 확장이 용이합니다.**

> 요구사항) 배너 정보 외에 뱃지와 공지사항 정보를 추가해주세요.

- 코드 예시

  > 앞서 Output 에서의 변경을 보신 것과는 달리, 이번에는 도메인 서비스로 한층 더 들어와서 코드 예시를 보겠습니다.

  ```kotlin
  ////////////
  // 기존 코드
  ////////////
  @Service
  class ContentAggService(
      @Qualifier("pdpBannerPrimaryAdapter") private val bannerPort: PdpBannerQueryPort
  ): ContentAggUseCase {
      override fun getContentAgg(productId: Long): ContentAgg {
          val banners = bannerPort.findByProductId(productId)
          return ContentAgg(pdpBanners = banners.toDomainObject())
      }
  }

  ////////////
  // 변경 코드
  ////////////
  @Service
  class ContentAggService(
      @Qualifier("pdpBannerPrimaryAdapter") private val bannerPort: PdpBannerQueryPort,
      @Qualifier("pdpBadgePrimaryAdapter") private val badgePort: PdpBadgeQueryPort // Badge 정보 추가
      @Qualifier("pdpNoticePrimaryAdapter") private val noticePort: PdpNoticeQueryPort // Notice 정보 추가
  ) : ContentAggUseCase {
      override fun getContentAgg(productId: Long): ContentAgg {
          val banners = bannerPort.findByProductId(productId)
          val badges = badgePort.findByProductId(productId) // Badge 정보 조회
          val notices = noticePort.findByProductId(productId) // Notice 정보 조회

          return ContentAgg(
              banners = banners.toDomainObject(),
              badges = badges.toDomainObject(), // Badge 정보 포함
              notices = notices.toDomainObject() // Notice 정보 포함
          )
      }
  }
  ```

  > 위 변경된 코드를 보면 알 수 있듯이, 하나의 Output Port 추가와 이를 Aggregate 하는 코드 몇줄만 추가되었습니다.
  > 이로써 큰 변경 없이 비즈니스 로직을 구현할 수 있도록 도메인 객체가 만들어졌습니다.

> 요구사항) DTO 레벨에서 캐시하지 않고 Domain 레벨에서 캐시할 수 있도록 해주세요.

- 코드 예시

  > 이번에는 캐시 컨트롤에 대한 예제로도 한번 살펴보겠습니다.

  ```kotlin
  ////////////
  // 기존 코드
  ////////////
  @Service
  class ContentAggService(
      @Qualifier("pdpBannerPrimaryAdapter") private val bannerPort: PdpBannerQueryPort,
      @Qualifier("pdpBadgePrimaryAdapter") private val badgePort: PdpBadgeQueryPort
  ): ContentAggUseCase {
      override fun getContentAgg(productId: Long): ContentAgg {
          val banners = bannerPort.findByProductId(productId)
          val badges = badgePort.findByProductId(productId)

          return ContentAgg(
              pdpBanners = banners.toDomainObject(),
              pdpBadges = badges.toDomainObject() // Badge 정보 포함
          )
      }
  }

  ////////////
  // 변경 코드
  ////////////
  interface ContentAggQueryPort : QueryPort<ContentAgg> // Content 애그리거트 조회 Output Port

  interface ContentAggCommandPort : CommandPort<ContentAgg> // Content 애그리거트 저장 Output Port

  @Service
  class ContentAggService(
      @Qualifier("pdpBannerPrimaryAdapter") private val bannerPort: PdpBannerQueryPort,
      private val contentAggQueryPort: ContentAggQueryPort,
      private val contentAggCommandPort: ContentAggCommandPort
  ): ContentAggUseCase {
      override fun getContentAgg(productId: Long): ContentAgg {
          // 캐시에 데이터가 존재한다면 그대로 사용
          contentAggQueryPort.findByProductId(productId)?.let {
              return it
          }

          // 캐시가 존재하지 않으면 데이터 조회
          val banners = bannerPort.findByProductId(productId)
          val badges = badgePort.findByProductId(productId)
          val contentAgg = ContentAgg(
              pdpBanners = banners.toDomainObject(),
              pdpBadges = badges.toDomainObject()
          )

          // 조회된 데이터를 저장하여 캐싱
          contentAggCommandPort.save(productId, contentAgg)

          return contentAgg
      }
  }
  ```

  > 이 역시 앞선 예제와 마찬가지로 간단한 Output Port 추가만으로 요구사항 변경이 가능하다는 것을 확인할 수 있습니다.

이번에는 쭉 앞쪽으로 이동해서 Input Port 쪽으로 와보겠습니다.

> 요구사항) PDP 선물하기 기능이 도입되었어요. 이로 인해서 PDP 에 노출하려는 컨텐츠가 기존과 많이 달라졌어요. 선물하기 PDP 를 구현해주세요.

- 코드 예시

  ```kotlin
  ////////////
  // 기존 코드
  ////////////
  interface PdpPagePort {
      suspend fun generate(productId: Long): PdpPage
  }

  @Service
  class PdpPageAdapter(
      private val pdpAggUseCase: PdpAggUseCase,
      private val pageUseCase: PdpPageUseCase,
      private val lineMarginUseCase: LineMarginUseCase
  ): PdpPagePort {
      override suspend fun generate(productId: Long): PdpPage = coroutineScope {
          // Step 1. 애그리거트(Aggregate) 루트 객체 생성
          val pdpAgg = pdpAggUseCase.getPdpAgg(productId)
          // Step 2. Server-Driven UI 컴포넌트 생성 및 배치
          val page = pageUseCase.generatePage(pdpAgg)
          // Step 3. 생성된 UI 컴포넌트들을 기준으로 컴포넌트 간 라인과 마진을 적용한다.
          val prettyPage = lineMarginUseCase.applyLineAndMargin(page)

          return@coroutineScope prettyPage
      }
  }

  ////////////
  // 변경 코드
  ////////////
  interface PdpPagePort {
      suspend fun generate(pdpAgg: PdpAgg): PdpPage
      suspend fun supports(pageType: String): Boolean // 추가된 메서드
  }

  // 반복되는 로직 분리
  abstract class BasePdpPageAdapter(
      private val pdpAggUseCase: PdpAggUseCase,
      private val lineMarginUseCase: LineMarginUseCase
  ) : PdpPagePort {
      suspend fun generatePage(productId: Long): PdpPage = coroutineScope {
          // Step 1. 애그리거트(Aggregate) 루트 객체 생성
          val pdpAgg = pdpAggUseCase.getPdpAgg(productId)
          // Step 2. Server-Driven UI 컴포넌트 생성 및 배치
          val page = generate(pdpAgg)
          // Step 3. 생성된 UI 컴포넌트들을 기준으로 컴포넌트 간 라인과 마진을 적용한다.
          return@coroutineScope lineMarginUseCase.applyLineAndMargin(page)
      }
  }

  // 기존 PDP 에 대한 대응
  @Service
  class DefaultPdpPageAdapter(
      pdpAggUseCase: PdpAggUseCase,
      private val pageUseCase: PdpPageUseCase,
      lineMarginUseCase: LineMarginUseCase
  ) : BasePdpPageAdapter(pdpAggUseCase, lineMarginUseCase) {
      override suspend fun supports(pageType: String): Boolean = pageType == "default"

      override suspend fun generate(pdpAgg: PdpAgg): PdpPage = pageUseCase.generatePage(pdpAgg)
  }

  // 요구사항으로 받은 선물하기 PDP 에 대한 대응
  @Service
  class GiftPdpPageAdapter(
      pdpAggUseCase: PdpAggUseCase,
      private val pageUseCase: PdpPageUseCase,
      lineMarginUseCase: LineMarginUseCase
  ) : BasePdpPageAdapter(pdpAggUseCase, lineMarginUseCase) {
      override suspend fun supports(pageType: String): Boolean = pageType == "gift"

      override suspend fun generate(pdpAgg: PdpAgg): PdpPage = pageUseCase.generateGiftPage(pdpAgg)
  }

  @RestController
  @RequestMapping("/pdp")
  class PdpController(
      private val pagePorts: List<PdpPagePort>
  ) {
      @GetMapping("/{productId}")
      fun getPdpPage(
          @PathVariable productId: Long,
          @RequestParam(defaultValue = "default") pageType: String // 파라미터 추가
      ): PdpPage = runBlocking {
          val generator = pagePorts.find { it.supports(pageType) }
              ?: throw IllegalArgumentException("Unsupported page type: $pageType")
          return (generator as BasePdpPageAdapter).generatePage(productId)
      }
  }
  ```

  > PdpPagePort 를 인터페이스로 유지하여 PDP 유형별 다중 구현이 가능하도록 처리하였고 abstract class 를 추가하여 공통 로직을 분리하였습니다.
  > 추후에 비슷한 요구사항을 받았을 때 class GiftPdpPageAdapter 와 같이 하나의 Port 구현체 추가만으로도 Controller, Port 에 대한 변경 없이 대응이 가능해졌습니다.

이로써 Controller → Input Port → Domain → Output Port 흐름에 있어 각 모든 단계마다 코드의 큰 수정 없이 & 비즈니스 로직 변경 없이 요구사항이 반영이 가능하다는 것을 확인하였습니다.

그런데 코드들을 보면서 느낀 점이 있으신가요? 각 계층은 모두 Port 와 Use Case 라는 인터페이스로만 통신한다는 점을 알 수 있는데요. 이것은 헥사고날 아키텍처의 가장 큰 특징이며, 이로인한 Mocking 이 원활할 수 있겠다라는 것을 직감적으로 느낄 수 있습니다.

다음 예시에서 테스트가 용이해진 장점에 대해 알아보겠습니다.

### **이점3) Mocking 원활해지고 테스트 코드 작성이 용이해집니다.**

첫번째 예시로 DB 조회를 통해 배너 정보를 가져오는 부분에 대해 테스트 코드를 작성해보겠습니다.

다음 코드는 JPA 관련 테스트 코드를 레이어드 아키텍처와 헥사고날 아키텍처에서 서로 비교해본 예시입니다.

> 요구사항) RDB 를 사용하는 외부 호출부에 테스트 코드를 작성해주세요. (레이어드 아키텍처 vs. 헥사고날 아키텍처 비교)

- 레이어드 아키텍처 테스트 코드 예시

  ```kotlin
  // 레이어드 아키텍처 - JPA Repository 직접 사용
  @Service
  class ProductService(private val productRepository: ProductRepository) {
      fun getProduct(id: Long): Product {
          return productRepository.findById(id).orElseThrow { RuntimeException("Product not found") }
      }
  }

  // JPA Repository (영속성 계층 포함)
  interface ProductRepository : JpaRepository<Product, Long>

  // 레이어드 아키텍처 테스트 코드
  @SpringBootTest
  @ExtendWith(SpringExtension::class)
  class ProductServiceTest {
      @Autowired
      private lateinit var productService: ProductService

      @MockBean
      private lateinit var productRepository: ProductRepository

      @Test
      fun `상품 조회 - 존재하는 상품`() {
          val product = Product(id = 1L, name = "Test Product")
          given(productRepository.findById(1L)).willReturn(Optional.of(product))

          val result = productService.getProduct(1L)

          assertEquals("Test Product", result.name)
      }
  }
  ```

  > 위 코드를 보면 ProductRepository 가 @Repository 로 동작하며, JPA 를 사용해야 테스트가 가능한 것을 볼 수 있습니다. 즉, JPA 관련 불필요한 설정과 의존성이 테스트에 남아있게 됩니다. Mocking 은 가능하지만 복잡한 설정이 필요하게 됩니다.
  > ProductRepository 인터페이스를 직접 Mocking 하고는 있지만, 향후 변경이 발생하면 MockBean 이 설정이 추가로 필요하게 됩니다.
  > 이것이 바로 우리가 PR 이 올라오면 변경점들이 많게 느껴지는 이유 중 하나입니다.
  > 테스트 속도를 저하시키는 @SpringBootTest 를 사용하게 되는 것도 JPA Repository 사용을 위해 JPA 설정을 로드하고 Repository 를 정상 주입하기 위해서입니다.
  > 하지만 헥사고날 아키텍처는 Output Port 에 대해서만 Mocking 하면 되므로 JPA 나 복잡한 설정 없이 테스트가 가능합니다.
  >
  > 다음 헥사고날 아키텍처 테스트 코드를 보겠습니다.

- 헥사고날 아키텍처 테스트 코드 예시

  ```kotlin
  // 헥사고날 아키텍처 - Port (Interface) 사용
  interface ProductPort {
      fun findById(id: Long): Product?
  }

  // UseCase - Repository 대신 Port 사용
  class ProductUseCase(private val productPort: ProductPort) {
      fun getProduct(id: Long): Product {
          return productPort.findById(id) ?: throw RuntimeException("Product not found")
      }
  }

  // 헥사고날 아키텍처 테스트 코드
  @ExtendWith(MockitoExtension::class)
  class ProductUseCaseTest {
      @Mock
      private lateinit var productPort: ProductPort

      private lateinit var productUseCase: ProductUseCase

      @BeforeEach
      fun setUp() {
          productUseCase = ProductUseCase(productPort)
      }

      @Test
      fun `상품 조회 - 존재하는 상품`() {
          val product = Product(id = 1L, name = "Test Product")
          `when`(productPort.findById(1L)).thenReturn(product)

          val result = productUseCase.getProduct(1L)

          assertEquals("Test Product", result.name)
      }
  }
  ```

  > 위 코드를 보면 알 수 있듯이 JPA 설정이 불필요하여 테스트가 단순해졌습니다.
  > @SpringBootTest, @Autowired가 불필요해졌기 때문에 테스트 속도가 빨라졌습니다.
  > 또한 @Mock 을 사용하여 순수한 단위 테스트(Unit Test) 가 가능해졌습니다.
  > 실행 속도 측면에서나 테스트 코드 작성 및 유지보수 측면에서에서 보나 모두 후자가 유리한 점을 알 수 있습니다.

이번에는 기술 스택 변경에 따른 유연성을 검증해보겠습니다.

> 요구사항) DB, Storage 엔진 변경 등 기술 스택이 변경될 수도 있을텐데, 이를 테스트 코드 관점에서 유연성을 보여주세요.

- 코드 예시

  ```kotlin
  ////////////
  // 기존 코드
  ////////////
  @Component
  class PdpBannerRedisAdapter(private val redisTemplate: RedisTemplate<String, List<PdpBanner>>)
      : PdpBannerQueryPort, PdpBannerCommandPort {
      override fun findByProductId(productId: Long): List<PdpBanner>? {
          return redisTemplate.opsForValue().get("pdp-banner:$productId")
      }

      override fun save(productId: Long, banners: List<PdpBanner>) {
          redisTemplate.opsForValue().set("pdp-banner:$productId", banners)
      }
  }

  @Component
  class PdpBannerPrimaryAdapter(
      @Qualifier("pdpBannerRedisAdapter") private val redisQueryPort: PdpBannerQueryPort,
      @Qualifier("pdpBannerRedisAdapter") private val redisCommandPort: PdpBannerCommandPort,
      @Qualifier("pdpBannerApiAdapter") private val apiQueryPort: PdpBannerQueryPort
  ) : PdpBannerQueryPort {
      override fun findByProductId(productId: Long): List<PdpBanner>? {
          return redisQueryPort.findByProductId(productId)
              ?: apiQueryPort.findByProductId(productId)?.also {
                  if (it.isNotEmpty()) {
                      redisCommandPort.save(productId, it)
                  }
              }
      }
  }

  ////////////
  // 신규 코드
  ////////////
  @Component
  class PdpBannerValkeyAdapter(private val valkeyClient: ValkeyClient)
      : PdpBannerQueryPort, PdpBannerCommandPort {
      override fun findByProductId(productId: Long): List<PdpBanner>? {
          return valkeyClient.get<List<PdpBanner>>("pdp-banner:$productId")
      }

      override fun save(productId: Long, banners: List<PdpBanner>) {
          valkeyClient.set("pdp-banner:$productId", banners)
      }
  }

  @Component
  class PdpBannerPrimaryAdapter(
      @Qualifier("pdpBannerValkeyAdapter") private val valkeyQueryPort: PdpBannerQueryPort, // 주입되는 어댑터만 redis -> valkey 로 변경되었습니다.
      @Qualifier("pdpBannerValkeyAdapter") private val valkeyCommandPort: PdpBannerCommandPort,
      @Qualifier("pdpBannerApiAdapter") private val apiQueryPort: PdpBannerQueryPort
  ) : PdpBannerQueryPort {
      override fun findByProductId(productId: Long): List<PdpBanner>? {
          return valkeyQueryPort.findByProductId(productId)
              ?: apiQueryPort.findByProductId(productId)?.also {
                  if (it.isNotEmpty()) {
                      valkeyCommandPort.save(productId, it)
                  }
              }
      }
  }

  ////////////
  // 테스트 코드
  ////////////
  @ExtendWith(MockitoExtension::class)
  class PdpBannerPrimaryAdapterTest {
      @Mock
      private lateinit var globalCacheQueryPort: PdpBannerQueryPort  // 글로벌 캐시 조회 포트 (Redis, Valkey 등 사용 가능)

      @Mock
      private lateinit var globalCacheCommandPort: PdpBannerCommandPort  // 글로벌 캐시 저장 포트

      @Mock
      private lateinit var apiQueryPort: PdpBannerQueryPort  // 외부 API 조회 포트

      private lateinit var primaryAdapter: PdpBannerPrimaryAdapter

      @BeforeEach
      fun setUp() {
          primaryAdapter = PdpBannerPrimaryAdapter(globalCacheQueryPort, globalCacheCommandPort, apiQueryPort)
      }

      @Test
      fun `글로벌 캐시에 데이터가 있으면 API를 호출하지 않고 반환한다`() {
          // Given
          val productId = 100L
          val banners = listOf(PdpBanner(id = 1L, title = "Banner 1"))

          `when`(globalCacheQueryPort.findByProductId(productId)).thenReturn(banners)

          // When
          val result = primaryAdapter.findByProductId(productId)

          // Then
          assertNotNull(result)
          assertEquals(1, result?.size)
          assertEquals("Banner 1", result?.first()?.title)

          // Verify (API 호출이 발생하지 않아야 함)
          verify(apiQueryPort, never()).findByProductId(any())

          // Verify (글로벌 캐시에 데이터가 있기 때문에 저장 로직이 실행되지 않아야 함)
          verify(globalCacheCommandPort, never()).save(any(), any())
      }

      @Test
      fun `글로벌 캐시에 데이터가 없고 API에서 가져오면 글로벌 캐시에 저장 후 반환한다`() {
          // Given
          val productId = 200L
          val banners = listOf(PdpBanner(id = 2L, title = "Banner 2"))

          `when`(globalCacheQueryPort.findByProductId(productId)).thenReturn(null)  // 글로벌 캐시에 데이터 없음
          `when`(apiQueryPort.findByProductId(productId)).thenReturn(banners)  // API에서 데이터 조회

          // When
          val result = primaryAdapter.findByProductId(productId)

          // Then
          assertNotNull(result)
          assertEquals(1, result?.size)
          assertEquals("Banner 2", result?.first()?.title)

          // Verify (API가 호출되었는지 확인)
          verify(apiQueryPort).findByProductId(productId)

          // Verify (API에서 조회한 데이터를 글로벌 캐시에 저장했는지 확인)
          verify(globalCacheCommandPort).save(productId, banners)
      }

      @Test
      fun `글로벌 캐시와 API 모두에 데이터가 없으면 null을 반환한다`() {
          // Given
          val productId = 300L
          `when`(globalCacheQueryPort.findByProductId(productId)).thenReturn(null)  // 글로벌 캐시에 데이터 없음
          `when`(apiQueryPort.findByProductId(productId)).thenReturn(null)  // API에도 데이터 없음

          // When
          val result = primaryAdapter.findByProductId(productId)

          // Then
          assertNull(result)

          // Verify (API 호출이 발생했는지 확인)
          verify(apiQueryPort).findByProductId(productId)

          // Verify (글로벌 캐시 저장이 수행되지 않아야 함)
          verify(globalCacheCommandPort, never()).save(any(), any())
      }
  }
  ```

  > 테스트 코드를 보면 알 수 있듯이 특정 캐시 기술에 의존하지 않고 헥사고날 아키텍처의 인터페이스만을 활용하여 테스트가 수행된 것을 알 수 있습니다.
  > 즉, Redis → Valkey 로 기술 스택이 변경된다고 할지라도 테스트 코드는 변경없이 유지되며 올바른 검증을 수행합니다.
  > 이는 위 사례로 든 Output Port 에 대한 검증 뿐 아니라, 도메인 로직을 구현하는 서비스 코드에서도 마찬가지로 기술 스택 변경에 따른 영향을 받지 않습니다.

**이 외에도 Mocking 이 원활해짐으로 인해 얻는 장점들이 많습니다. 추가적인 예시를 들면 다음과 같습니다.**

1. API 개발이 빨라집니다.
   1. 내가 만드는 API 작업에 있어서 mock 을 우선 제공하려할때 용이합니다.
   2. 타팀 디펜던시를 받고 있는 경우 우선 mock 처리하여 나의 개발 진행이 용이합니다.
2. JVM 웜업 전용 API 만들기에도 용이합니다.
   1. 레디스, RDB, 외부 API 호출 등 모든 Output Port 영역은 Mock 처리하고 그 외 모든 클래스의 웜업에 집중할 수 있습니다.
   2. Output Port 전용 웜업을 구현하기 용이합니다.
3. 단위 테스트 작성이 빠르다보니 테스트 커버리지를 올리기에 용이합니다.

## 마무리

이렇게 해서 Domain-Driven 헥사고날 아키텍처를 코드 예시를 통해 알아보는 시간을 가졌습니다.

이 아키텍처의 목표를 요약하자면 이렇습니다.

1. Port 를 이용한 패턴으로 비즈니스 로직 및 도메인 로직을 외부의 입출력과 명확하게 분리한다.
2. 비즈니스 요구사항을 해결하기 위해 단순히 Service 클래스로만 구성하는 것이 아니라 Use Case 인터페이스 방식을 활용한다.
3. DDD(Domain-Driven Design) 와 헥사고날 아키텍처는 서로 보완 관계에 있다. DDD 를 이용하여 도메인 중심적 설계를 하고, 헥사고날 아키텍처는 도메인 모델이 효과적으로 사용될 수 있도록 구조를 제공한다.
4. 도메인 모델을 구성하는 데에 어느정도 복잡도가 있는 경우, 애그리거트 모델을 이용하여 설계할 수 있다.

다음 시간에 기회가 된다면 앞서 소개한 장점과 대비될 수 있는 헥사고날 아키텍처를 사용할때 발생할 수 있는 단점이나 트레이드 오프에 대해 사례를 들어 나열해보고, 이를 어떻게 개선했는지에 대해서도 소개하는 시간을 가져보겠습니다.

감사합니다. 🙂
