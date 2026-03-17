# City Wiring

## Core contract relationships

### CityRegistry
- optional hook to `CityHistory`
- optional hook to `CityDistricts`

### CityLand
- optional hook to `CityStatus`
- optional hook to `CityHistory`

### CityStatus
- authorized callers can touch activity and record maintenance

### CityHistory
- authorized callers can initialize and update plot provenance

### CityDistricts
- authorized callers can assign or auto-assign districts

---

## Recommended wiring order after deployment

1. Deploy `CityConfig`
2. Deploy `CityRegistry`
3. Deploy `CityHistory`
4. Deploy `CityStatus`
5. Deploy `CityLand`
6. Deploy `CityDistricts`
7. Deploy `CityValidation`

---

## Owner setup actions

### Registry
- `setCityHistory(historyAddress)`
- `setCityDistricts(districtsAddress)`

### Land
- `setHooks(statusAddress, historyAddress)`

### History
- `setAuthorizedCaller(registryAddress, true)`
- `setAuthorizedCaller(landAddress, true)`

### Status
- `setAuthorizedCaller(landAddress, true)`

### Districts
- `setAuthorizedCaller(registryAddress, true)`