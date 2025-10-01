# Runaway Labs - Strava Data Export Entity Relationship Diagram

## ERD Overview

```mermaid
erDiagram
    %% Core Entities
    athletes {
        bigint id PK
        uuid auth_user_id FK
        varchar email
        varchar first_name
        varchar last_name
        varchar sex
        text description
        decimal weight
        varchar city
        varchar state
        varchar country
        timestamp created_at
    }

    athlete_stats {
        bigint id PK
        bigint athlete_id FK
        int count
        decimal distance
        bigint moving_time
        bigint elapsed_time
        decimal elevation_gain
        int achievement_count
        decimal ytd_distance
        timestamp created_at
        timestamp updated_at
    }

    activity_types {
        int id PK
        varchar name
        varchar category
        text description
    }

    activities {
        bigint id PK
        bigint athlete_id FK
        int activity_type_id FK
        varchar name
        text description
        timestamp activity_date
        int elapsed_time
        int moving_time
        decimal distance
        decimal elevation_gain
        decimal elevation_loss
        decimal elevation_low
        decimal elevation_high
        decimal max_speed
        decimal average_speed
        int max_heart_rate
        int average_heart_rate
        int max_watts
        int average_watts
        int weighted_average_watts
        int max_cadence
        int average_cadence
        int calories
        decimal max_temperature
        decimal average_temperature
        varchar weather_condition
        decimal humidity
        decimal wind_speed
        text map_polyline
        text map_summary_polyline
        decimal start_latitude
        decimal start_longitude
        decimal end_latitude
        decimal end_longitude
        boolean commute
        boolean flagged
        boolean with_pet
        boolean competition
        varchar filename
        bigint gear_id FK
        timestamp created_at
    }

    %% Gear Entities
    brands {
        int id PK
        varchar name
        text description
    }

    models {
        int id PK
        int brand_id FK
        varchar name
        varchar category
    }

    gear {
        bigint id PK
        bigint athlete_id FK
        int brand_id FK
        int model_id FK
        varchar gear_type
        varchar name
        boolean is_primary
        bigint total_distance
        timestamp created_at
    }

    %% Geographic Entities
    routes {
        bigint id PK
        bigint athlete_id FK
        varchar name
        varchar filename
        text description
        timestamp created_at
    }

    segments {
        bigint id PK
        bigint activity_id FK
        varchar name
        decimal start_latitude
        decimal start_longitude
        decimal end_latitude
        decimal end_longitude
        timestamp created_at
    }

    starred_routes {
        bigint athlete_id FK
        bigint route_id FK
        timestamp starred_at
    }

    starred_segments {
        bigint athlete_id FK
        bigint segment_id FK
        timestamp starred_at
    }

    %% Social Entities
    follows {
        bigint follower_id FK
        bigint following_id FK
        varchar status
        boolean is_favorite
        timestamp created_at
    }

    comments {
        bigint id PK
        bigint activity_id FK
        bigint athlete_id FK
        text content
        timestamp comment_date
    }

    reactions {
        bigint id PK
        varchar parent_type
        bigint parent_id
        bigint athlete_id FK
        varchar reaction_type
        timestamp reaction_date
    }

    %% Club Entities
    clubs {
        bigint id PK
        varchar name
        text description
        varchar club_type
        varchar sport
        varchar city
        varchar state
        varchar country
        varchar website
        varchar cover_photo
        varchar club_picture
        timestamp created_at
    }

    memberships {
        bigint athlete_id FK
        bigint club_id FK
        timestamp join_date
        varchar status
    }

    %% Challenge/Goal Entities
    challenges {
        bigint id PK
        varchar name
        varchar challenge_type
        timestamp start_date
        timestamp end_date
        text description
    }

    challenge_participations {
        bigint athlete_id FK
        bigint challenge_id FK
        timestamp join_date
        boolean completed
        timestamp completion_date
    }

    goals {
        bigint id PK
        bigint athlete_id FK
        varchar goal_type
        varchar activity_type
        decimal target_value
        timestamp start_date
        timestamp end_date
        bigint segment_id FK
        varchar time_period
        int interval_time
    }

    running_goals {
        bigint id PK
        bigint athlete_id FK
        varchar title
        varchar goal_type
        decimal target_value
        timestamp deadline
        boolean is_active
        boolean is_completed
        decimal current_progress
        timestamp created_at
        timestamp updated_at
        timestamp completed_at
    }

    daily_commitments {
        bigint id PK
        bigint athlete_id FK
        date commitment_date
        varchar activity_type
        boolean is_fulfilled
        timestamp fulfilled_at
        timestamp created_at
        timestamp updated_at
    }

    %% Media Entities
    media {
        bigint id PK
        bigint activity_id FK
        varchar filename
        text caption
        varchar media_type
        timestamp created_at
    }

    %% System Entities
    connected_apps {
        bigint id PK
        bigint athlete_id FK
        varchar app_name
        boolean enabled
        timestamp connected_at
    }

    logins {
        bigint id PK
        bigint athlete_id FK
        varchar ip_address
        varchar login_source
        timestamp login_datetime
    }

    contacts {
        bigint id PK
        bigint athlete_id FK
        bigint contact_athlete_id FK
        varchar contact_type
        varchar contact_value
        varchar contact_source
        varchar contact_name
    }

    %% Relationships
    athletes ||--|| athlete_stats : "has"
    athletes ||--o{ activities : "performs"
    athletes ||--o{ gear : "owns"
    athletes ||--o{ routes : "creates"
    athletes ||--o{ follows : "follower"
    athletes ||--o{ follows : "following"
    athletes ||--o{ comments : "writes"
    athletes ||--o{ reactions : "makes"
    athletes ||--o{ memberships : "joins"
    athletes ||--o{ challenge_participations : "participates"
    athletes ||--o{ goals : "sets"
    athletes ||--o{ running_goals : "creates"
    athletes ||--o{ daily_commitments : "makes"
    athletes ||--o{ starred_routes : "stars"
    athletes ||--o{ starred_segments : "stars"
    athletes ||--o{ connected_apps : "connects"
    athletes ||--o{ logins : "logs_in"
    athletes ||--o{ contacts : "has_contact"
    athletes ||--o{ media : "uploads"

    activity_types ||--o{ activities : "categorizes"
    activities ||--o{ segments : "contains"
    activities ||--o{ comments : "receives"
    activities ||--o{ reactions : "receives"
    activities ||--o{ media : "includes"

    brands ||--o{ models : "manufactures"
    brands ||--o{ gear : "makes"
    models ||--o{ gear : "specifies"
    gear ||--o{ activities : "used_in"

    routes ||--o{ starred_routes : "starred_as"
    segments ||--o{ starred_segments : "starred_as"
    segments ||--o{ goals : "targets"

    clubs ||--o{ memberships : "has_members"
    challenges ||--o{ challenge_participations : "participated_in"
```

## Key Relationships

### Primary Relationships
1. **Athletes** are the central entity, connected to all user-generated content
2. **Activities** are the core data points, linked to athletes, gear, and geographic data
3. **Gear** (bikes/shoes) connects to activities through usage tracking
4. **Social connections** through follows, comments, and reactions

### Secondary Relationships
1. **Geographic data** through routes and segments
2. **Club participation** through memberships
3. **Challenge participation** and goal setting
4. **Media attachments** to activities

### Reference Data
1. **Activity types** for categorization
2. **Brands and models** for gear normalization
3. **Challenges** as reusable entities

## Normalization Benefits

1. **Eliminates redundancy** in brand/model data
2. **Supports referential integrity** across social connections
3. **Enables efficient querying** of activity patterns
4. **Scales for multiple athletes** in future expansions
5. **Maintains audit trails** through timestamps