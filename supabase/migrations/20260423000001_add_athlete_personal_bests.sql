-- athlete_personal_bests
-- Stores the best recorded time for each standard race distance per athlete.
-- Populated by PersonalBestService from the full activities history.

create table if not exists athlete_personal_bests (
    id               bigserial primary key,
    athlete_id       bigint       not null references athletes(id) on delete cascade,
    distance_label   varchar(32)  not null, -- 'mile', '5k', '10k', 'half_marathon', 'marathon'
    distance_meters  numeric      not null,
    time_seconds     integer      not null check (time_seconds > 0),
    activity_id      bigint       references activities(id) on delete set null,
    achieved_at      timestamptz  not null,
    created_at       timestamptz  not null default now(),
    updated_at       timestamptz  not null default now(),

    unique (athlete_id, distance_label)
);

-- Index for fast per-athlete lookups
create index if not exists idx_athlete_personal_bests_athlete
    on athlete_personal_bests (athlete_id);

-- RLS: athletes can only read/write their own PRs
alter table athlete_personal_bests enable row level security;

create policy "Athletes can view own PRs"
    on athlete_personal_bests for select
    using (
        athlete_id in (
            select id from athletes where auth_user_id = auth.uid()
        )
    );

create policy "Athletes can upsert own PRs"
    on athlete_personal_bests for insert
    with check (
        athlete_id in (
            select id from athletes where auth_user_id = auth.uid()
        )
    );

create policy "Athletes can update own PRs"
    on athlete_personal_bests for update
    using (
        athlete_id in (
            select id from athletes where auth_user_id = auth.uid()
        )
    );
