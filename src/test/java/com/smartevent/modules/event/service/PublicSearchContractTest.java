package com.smartevent.modules.event.service;
import java.time.*;
import java.math.BigDecimal;
import com.smartevent.modules.event.dto.request.PublicSearchFilter;
import com.smartevent.modules.event.repository.*;
import com.smartevent.modules.event.service.impl.EventQueryService;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class PublicSearchContractTest {
    @Test void fixedClockReachesQueryAndStablePagination() {
        var events = mock(EventRepository.class);
        var now = Instant.parse("2026-10-30T00:00:00Z");
        var stable = PageRequest.of(0, 10, Sort.by("startTime", "id"));
        when(events.searchPublishedFiltered(now, null, null, null, null, null, null, "LTE", stable)).thenReturn(Page.empty(stable));
        var service = new EventQueryService(Clock.fixed(now, ZoneOffset.UTC), events,
            mock(CategoryRepository.class), mock(VenueRepository.class), mock(EventFileRepository.class), mock(EventCategoryRepository.class));
        var result = service.searchPublishedEvents(PageRequest.of(0, 10), null, null, null,
            new PublicSearchFilter(null, null, null, null));
        assertEquals(0, result.totalElements());
        verify(events).searchPublishedFiltered(now, null, null, null, null, null, null, "LTE", stable);
        verify(events, never()).findPriceEvidence(any(), any(), any(), any());
    }
    @Test void rejectsInvalidRangeComparisonAndPrice() {
        var now = Instant.parse("2026-10-30T00:00:00Z");
        assertThrows(RuntimeException.class, () -> new PublicSearchFilter(now, now, null, null));
        assertThrows(RuntimeException.class, () -> new PublicSearchFilter(null, null, BigDecimal.ONE, "EQ"));
        assertThrows(RuntimeException.class, () -> new PublicSearchFilter(null, null, new BigDecimal("-1"), "LT"));
    }
}
