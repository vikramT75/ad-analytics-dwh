import csv
import logging
import random
from datetime import datetime, timedelta
from pathlib import Path
from typing import List, Dict, Any, Tuple
from faker import Faker

# Logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# Initialize Faker and Constants
fake = Faker()
Faker.seed(42)
random.seed(42)

BASE_DIR = Path(r"E:\awat\sql-proj\datasets")


def create_directories() -> None:
    directories = ["source_crm", "source_device", "source_dsp"]
    for d in directories:
        dir_path = BASE_DIR / d
        dir_path.mkdir(parents=True, exist_ok=True)
    logger.info(f"Ensured directory exists: {dir_path}")


def write_csv(filepath: Path, headers: List[str], data: List[Dict[str, Any]]) -> None:
    with open(filepath, mode="w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=headers)
        writer.writeheader()
        writer.writerows(data)
    logger.info(f"Wrote {len(data)} rows to {filepath}")


def generate_advertisers() -> List[Dict[str, Any]]:
    logger.info("Generating advertisers...")
    advertisers = []

    industries = [
        "Technology",
        "Retail",
        "Finance",
        "Healthcare",
        "Entertainment",
        "Travel",
        "Gaming",
    ]
    countries = [
        "United States",
        "India",
        "United Kingdom",
        "Canada",
        "Australia",
        "Germany",
    ]
    country_weights = [40, 20, 15, 10, 10, 5]

    statuses = ["ACTIVE"] * 70 + ["PAUSED"] * 15 + ["SUSPENDED"] * 15

    for i in range(1, 51):
        adv_id = f"ADV-{i:04d}"
        country = random.choices(countries, weights=country_weights, k=1)[0]
        status = random.choice(statuses)

        # Inject dirty data logic will be applied at the end

        signup_date = fake.date_between(
            start_date=datetime(2020, 1, 1), end_date=datetime(2023, 12, 31)
        )

        advertisers.append(
            {
                "advertiser_id": adv_id,
                "company_name": fake.company(),
                "industry": random.choice(industries),
                "country": country,
                "account_status": status,
                "signup_date": signup_date.strftime("%Y-%m-%d"),
            }
        )

    # Inject dirty data: 5 'A', 3 'S'
    active_indices = [
        idx for idx, row in enumerate(advertisers) if row["account_status"] == "ACTIVE"
    ]
    suspended_indices = [
        idx
        for idx, row in enumerate(advertisers)
        if row["account_status"] == "SUSPENDED"
    ]

    for idx in random.sample(active_indices, min(5, len(active_indices))):
        advertisers[idx]["account_status"] = "A"

    for idx in random.sample(suspended_indices, min(3, len(suspended_indices))):
        advertisers[idx]["account_status"] = "S"

    write_csv(
        BASE_DIR / "source_crm" / "advertisers.csv",
        list(advertisers[0].keys()),
        advertisers,
    )
    return advertisers


def generate_campaigns(advertisers: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    logger.info("Generating campaigns...")
    campaigns = []

    objectives = ["AWARENESS"] * 30 + ["PERFORMANCE"] * 50 + ["RETARGETING"] * 20
    statuses = ["ACTIVE"] * 50 + ["COMPLETED"] * 35 + ["PAUSED"] * 15
    countries = [
        "United States",
        "Canada",
        "United Kingdom",
        "Australia",
        "India",
        "Germany",
    ]

    for i in range(1, 201):
        adv = random.choice(advertisers)
        cmp_id = f"CMP-{i:05d}"
        industry = adv["industry"]

        name_templates = [
            f"{industry} Brand Awareness Q{random.randint(1, 4)} 2024",
            f"{industry} Performance Drive {fake.month_name()}",
            f"{adv['company_name']} Global Reach",
            f"{adv['company_name']} Retargeting Batch {random.randint(1, 100)}",
        ]

        start_date = fake.date_between(
            start_date=datetime(2024, 1, 1), end_date=datetime(2024, 12, 31)
        )
        end_date = start_date + timedelta(days=random.randint(30, 180))

        target_geo_list = random.sample(countries, k=random.randint(1, 4))

        campaigns.append(
            {
                "campaign_id": cmp_id,
                "advertiser_id": adv["advertiser_id"],
                "campaign_name": random.choice(name_templates),
                "objective": random.choice(objectives),
                "budget_usd": round(random.uniform(10000, 500000), 2),
                "start_date": start_date.strftime("%Y-%m-%d"),
                "end_date": end_date.strftime("%Y-%m-%d"),
                "status": random.choice(statuses),
                "target_geo": ",".join(target_geo_list),
            }
        )

    # Dirty data injection
    # Objectives
    for _ in range(10):
        idx = random.randint(0, len(campaigns) - 1)
        mapping = {"AWARENESS": "AWA", "PERFORMANCE": "PERF", "RETARGETING": "RET"}
        curr_obj = campaigns[idx]["objective"]
        if curr_obj in mapping:
            campaigns[idx]["objective"] = mapping[curr_obj]

    # Budget outliers
    for idx in random.sample(range(len(campaigns)), 5):
        pass  # placeholder to assign to 5 specific spots
    budget_dirty = random.sample(range(len(campaigns)), 5)
    for i, idx in enumerate(budget_dirty):
        if i < 3:
            campaigns[idx]["budget_usd"] = round(random.uniform(-5000, -100), 2)
        else:
            campaigns[idx]["budget_usd"] = 0.0

    # Status codes
    status_dirty = random.sample(range(len(campaigns)), 5)
    for idx in status_dirty:
        curr_status = campaigns[idx]["status"]
        if len(curr_status) > 1:  # Only if it hasn't been modified
            campaigns[idx]["status"] = curr_status[0]

    write_csv(
        BASE_DIR / "source_crm" / "campaigns.csv", list(campaigns[0].keys()), campaigns
    )
    return campaigns


def generate_device_profiles() -> List[Dict[str, Any]]:
    logger.info("Generating device profiles...")
    devices = []

    os_types = (
        ["iOS"] * 38
        + ["Android"] * 45
        + ["Windows"] * 10
        + ["macOS"] * 5
        + ["Unknown"] * 2
    )
    device_types = (
        ["mobile"] * 58
        + ["tablet"] * 15
        + ["desktop"] * 20
        + ["CTV"] * 5
        + ["Unknown"] * 2
    )
    countries = ["US", "IN", "GB", "CA", "AU", "DE"]
    country_weights = [48, 22, 12, 7, 7, 4]
    languages = ["en", "hi", "es", "fr", "de", "zh"]
    lang_weights = [60, 15, 8, 7, 5, 5]
    age_bands = ["18-24", "25-34", "35-44", "45-54", "55+"]
    age_weights = [20, 30, 25, 15, 10]

    for i in range(1, 10001):
        dev_id = f"DEV-{i:07d}"
        devices.append(
            {
                "device_id": dev_id,
                "os_type": random.choice(os_types),
                "device_type": random.choice(device_types),
                "country": random.choices(countries, weights=country_weights, k=1)[0],
                "language": random.choices(languages, weights=lang_weights, k=1)[0],
                "age_band": random.choices(age_bands, weights=age_weights, k=1)[0],
            }
        )

    # Dirty data
    ios_indices = [idx for idx, row in enumerate(devices) if row["os_type"] == "iOS"]
    android_indices = [
        idx for idx, row in enumerate(devices) if row["os_type"] == "Android"
    ]

    for idx in random.sample(ios_indices, min(20, len(ios_indices))):
        devices[idx]["os_type"] = "ios"
    for idx in random.sample(android_indices, min(15, len(android_indices))):
        devices[idx]["os_type"] = "ANDROID"

    mobile_indices = [
        idx for idx, row in enumerate(devices) if row["device_type"] == "mobile"
    ]
    tablet_indices = [
        idx for idx, row in enumerate(devices) if row["device_type"] == "tablet"
    ]

    for idx in random.sample(mobile_indices, min(10, len(mobile_indices))):
        devices[idx]["device_type"] = "mob"
    for idx in random.sample(tablet_indices, min(8, len(tablet_indices))):
        devices[idx]["device_type"] = "tab"

    write_csv(
        BASE_DIR / "source_device" / "device_profiles.csv",
        list(devices[0].keys()),
        devices,
    )
    return devices


def generate_app_installs(devices: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    logger.info("Generating app installs...")
    installs = []

    # 50 predefined apps
    app_catalog = []
    categories = [
        ("Gaming", 10),
        ("Social", 8),
        ("Shopping", 8),
        ("Finance", 8),
        ("Health", 8),
        ("News", 8),
    ]

    app_counter = 1
    for cat, count in categories:
        for _ in range(count):
            app_id = f"APP-{app_counter:03d}"
            app_catalog.append(
                {
                    "app_id": app_id,
                    "app_name": f"{fake.word().capitalize()} {cat}",
                    "app_category": cat,
                }
            )
            app_counter += 1

    device_ids = [d["device_id"] for d in devices]

    for i in range(1, 30001):
        app = random.choice(app_catalog)
        dt = fake.date_time_between(
            start_date=datetime(2024, 1, 1), end_date=datetime(2024, 12, 31)
        )

        installs.append(
            {
                "install_id": f"INS-{i:08d}",
                "device_id": random.choice(device_ids),
                "app_id": app["app_id"],
                "app_name": app["app_name"],
                "app_category": app["app_category"],
                "install_date": dt.strftime("%Y-%m-%d %H:%M:%S"),
            }
        )

    # Future dates
    for idx in random.sample(range(len(installs)), 50):
        future_dt = fake.date_time_between(
            start_date=datetime(2025, 6, 1), end_date=datetime(2025, 12, 31)
        )
        installs[idx]["install_date"] = future_dt.strftime("%Y-%m-%d %H:%M:%S")

    write_csv(
        BASE_DIR / "source_device" / "app_installs.csv",
        list(installs[0].keys()),
        installs,
    )
    return installs


def generate_impressions(
    devices: List[Dict[str, Any]], campaigns: List[Dict[str, Any]]
) -> List[Dict[str, Any]]:
    logger.info("Generating impressions...")
    impressions = []

    # Campaign weighting based on budget
    campaign_ids = [c["campaign_id"] for c in campaigns]
    campaign_weights = [max(1, int(c["budget_usd"] / 1000)) for c in campaigns]

    placements = ["BANNER", "VIDEO", "NATIVE", "INTERSTITIAL"]
    placement_weights = [40, 30, 20, 10]

    ad_formats = ["300x250", "728x90", "320x50", "16:9", "1x1"]
    format_weights = [30, 20, 25, 15, 10]

    # Pre-generate hour weights
    hour_weights = [1 if (h < 8 or h > 22) else 5 for h in range(24)]

    city_map = {
        "US": ["New York", "Los Angeles", "Chicago", "Houston", "Phoenix"],
        "IN": ["Mumbai", "Delhi", "Bangalore", "Hyderabad", "Chennai"],
        "GB": ["London", "Manchester", "Birmingham", "Leeds", "Glasgow"],
        "CA": ["Toronto", "Montreal", "Vancouver", "Calgary", "Edmonton"],
        "AU": ["Sydney", "Melbourne", "Brisbane", "Perth", "Adelaide"],
        "DE": ["Berlin", "Munich", "Frankfurt", "Hamburg", "Cologne"],
    }

    def generate_random_date_weighted():
        dt = fake.date_time_between(
            start_date=datetime(2024, 1, 1), end_date=datetime(2024, 12, 31)
        )
        hour = random.choices(range(24), weights=hour_weights, k=1)[0]
        return dt.replace(
            hour=hour, minute=random.randint(0, 59), second=random.randint(0, 59)
        )

    for i in range(1, 50001):
        dev = random.choice(devices)
        dev_country = dev["country"]

        # 15% chance of geo mismatch
        if random.random() < 0.15:
            avail = [c for c in city_map.keys() if c != dev_country]
            imp_country = random.choice(avail) if avail else dev_country
        else:
            imp_country = dev_country

        imp_city = random.choice(city_map.get(imp_country, ["Unknown"]))

        dt = generate_random_date_weighted()

        impressions.append(
            {
                "imp_id": f"IMP-{i:08d}",
                "device_id": dev["device_id"],
                "campaign_id": random.choices(
                    campaign_ids, weights=campaign_weights, k=1
                )[0],
                "event_ts": dt.strftime("%Y-%m-%d %H:%M:%S"),
                "bid_price": round(random.uniform(0.5, 15.0), 2),
                "geo_country": imp_country,
                "geo_city": imp_city,
                "placement_type": random.choices(
                    placements, weights=placement_weights, k=1
                )[0],
                "ad_format": random.choices(ad_formats, weights=format_weights, k=1)[0],
            }
        )

    # Inject negative, zero, and outlier bids
    dirty_bids = random.sample(range(len(impressions)), 30 + 20 + 15)
    for i, idx in enumerate(dirty_bids):
        if i < 30:
            impressions[idx]["bid_price"] = round(random.uniform(-5.0, -0.5), 2)
        elif i < 50:
            impressions[idx]["bid_price"] = 0.0
        else:
            impressions[idx]["bid_price"] = 999.99

    # Inject empty country
    for idx in random.sample(range(len(impressions)), 10):
        impressions[idx]["geo_country"] = ""

    # Inject 100 duplicates (same imp_id, slightly diff event_ts)
    dup_sources = random.sample(impressions, 100)
    for dup in dup_sources:
        new_dup = dup.copy()
        orig_dt = datetime.strptime(dup["event_ts"], "%Y-%m-%d %H:%M:%S")
        new_dt = orig_dt + timedelta(seconds=random.randint(1, 10))
        new_dup["event_ts"] = new_dt.strftime("%Y-%m-%d %H:%M:%S")
        impressions.append(new_dup)

    write_csv(
        BASE_DIR / "source_dsp" / "impressions.csv",
        list(impressions[0].keys()),
        impressions,
    )
    return impressions


def generate_clicks(impressions: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    logger.info("Generating clicks...")
    clicks = []

    # 2% of total distinct impressions
    target_count = int(len(impressions) * 0.02)
    selected_impressions = random.sample(impressions, target_count)

    for i, imp in enumerate(selected_impressions, 1):
        orig_dt = datetime.strptime(imp["event_ts"], "%Y-%m-%d %H:%M:%S")
        click_dt = orig_dt + timedelta(seconds=random.randint(1, 300))

        clicks.append(
            {
                "click_id": f"CLK-{i:07d}",
                "imp_id": imp["imp_id"],
                "device_id": imp["device_id"],
                "campaign_id": imp["campaign_id"],
                "event_ts": click_dt.strftime("%Y-%m-%d %H:%M:%S"),
            }
        )

    # Orphan clicks (invalid imp_id)
    for j in range(20):
        c_id = f"CLK-{len(clicks) + 1 + j:07d}"
        clicks.append(
            {
                "click_id": c_id,
                "imp_id": f"IMP-99999{j:03d}",
                "device_id": "DEV-0000001",
                "campaign_id": "CMP-00001",
                "event_ts": "2024-05-01 12:00:00",
            }
        )

    write_csv(BASE_DIR / "source_dsp" / "clicks.csv", list(clicks[0].keys()), clicks)
    return clicks


def main():
    logger.info("Starting dataset generation...")
    create_directories()

    advertisers = generate_advertisers()
    campaigns = generate_campaigns(advertisers)
    devices = generate_device_profiles()
    _ = generate_app_installs(devices)
    impressions = generate_impressions(devices, campaigns)
    _ = generate_clicks(impressions)

    logger.info("Dataset generation completed successfully.")


if __name__ == "__main__":
    main()
