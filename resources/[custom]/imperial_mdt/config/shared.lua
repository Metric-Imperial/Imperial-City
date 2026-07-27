ImperialMDT = {
    -- Departments and the qbx job name each maps to.
    departments = {
        police = { job = 'police', label = 'Police' },
        ambulance = { job = 'ambulance', label = 'EMS' },
        fire = { job = 'fire', label = 'Fire & Rescue' },
    },

    -- Minimum job grade to use each MDT capability (0 = any employee).
    permissions = {
        view = 0,
        createReport = 0,
        createCitation = 0,
        createArrest = 0,
        createWarrant = 1,
        createBolo = 0,
        viewMedicalRecords = 0,   -- ambulance only, enforced by department, not grade
        viewCriminalRecords = 0, -- police only
        deleteAny = 3,
    },

    -- Charge codes available to police reports (subset; extend freely).
    chargeCodes = {
        { code = '69.10', label = 'Petty Theft', fine = 500, jail = 0.5 },
        { code = '69.20', label = 'Grand Theft', fine = 2500, jail = 2 },
        { code = '13.40', label = 'Robbery', fine = 5000, jail = 4 },
        { code = '22.10', label = 'Assault', fine = 1500, jail = 2 },
        { code = '22.20', label = 'Aggravated Assault', fine = 4000, jail = 5 },
        { code = '31.50', label = 'Evading Police', fine = 3000, jail = 3 },
        { code = '40.10', label = 'Illegal Firearm Possession', fine = 5000, jail = 4 },
        { code = '50.30', label = 'Drug Possession', fine = 1000, jail = 1.5 },
        { code = '50.40', label = 'Drug Trafficking', fine = 6000, jail = 6 },
        { code = '90.10', label = 'Traffic Violation', fine = 250, jail = 0 },
    },
}
