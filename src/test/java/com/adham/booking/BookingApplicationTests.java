package com.adham.booking;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.jdbc.core.JdbcTemplate;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import static org.junit.jupiter.api.Assertions.assertEquals;

@SpringBootTest
@Testcontainers
class BookingApplicationTests {

    @Container
    @ServiceConnection
    static PostgreSQLContainer postgreSQLContainer = new PostgreSQLContainer("postgres:16");

    private final JdbcTemplate jdbc;

    BookingApplicationTests(@Autowired JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Test
    void migrationCreatesAllSixTables(){
        Long count = jdbc.queryForObject(
                "SELECT count(*) FROM information_schema.tables " +
                        "WHERE table_schema = 'public' AND table_name IN " +
                        "('users','services','instructor_services','slots','bookings','booking_events')",
                Long.class);
        assertEquals(6L, count, "Migration failed");
    }

    @Test
    void contextLoads() {
    }



}
